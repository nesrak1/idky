import logging
import os
import struct
import sys
import typing

# !! warning, bad rushed code !!

CS_TO_WAFFLE_ENT = {
    0: "NpcType::NONE",  # Null
    46: "NpcType::HV_TRIG",  # H/V trigger
    151: "NpcType::TEST",  # Test NPC
}

TEXT_TO_WAFFLE_TXT = (
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.?!,'\":;~@ "
)


class WaffleEntity:
    x: int
    y: int
    ascptr: str
    enttype: str
    flags: int

    def __init__(self):
        self.x = 0
        self.y = 0
        self.ascptr = ""
        self.enttype = ""
        self.flags = 0


def convert_tiles(pxmi: typing.BinaryIO, wfmo: typing.BinaryIO):
    pxm_data = pxmi.read()  # map tile data
    # pxa_data = (
    #     pxai.read()
    # )  # tile sheet collision data (currently unused since it's hardcoded)
    assert pxm_data[:4] == b"PXM\x10", "header doesn't match PXM\\x10"

    mapw = struct.unpack("<H", pxm_data[4:6])[0]
    maph = struct.unpack("<H", pxm_data[6:8])[0]
    mapw_valid = mapw == 16 or mapw == 32 or mapw == 64 or mapw == 128
    maph_valid = maph == 16 or maph == 32 or maph == 64 or maph == 128
    assert mapw_valid, f"map width must be 16, 32, 64, or 128, found {mapw}"
    assert maph_valid, f"map height must be 16, 32, or 64, found {maph}"

    # mapw_idx = [16, 32, 64, 128].index(mapw)
    # maph_idx = [16, 32, 64].index(maph)
    # mapw_jt = [6, 4, 2, 0][mapw_idx]
    # maph_jt = [6, 4, 2, 0][maph_idx]
    mapt_count = mapw * maph * 2

    # header
    wfmo.write(
        bytes(
            [
                # 00
                0x57,
                0x46,
                0x4D,
                0x50,
                # 04
                mapw,
                maph,
                mapt_count & 0xFF,
                (mapt_count >> 8) & 0xFF,
                # 08
                0,
                0,
                0,
                0,
                # 0C
                0,
                0,
                0,
                0,
            ]
        )
    )

    # tile data
    map_data_len = len(pxm_data)
    for i in range(8, map_data_len):
        pxm_tile_data = pxm_data[i]
        pxm_tile_x = pxm_tile_data & 0x0F
        pxm_tile_y = (pxm_tile_data & 0xF0) >> 4
        wfm_tile_x = pxm_tile_x << 1
        wfm_tile_y = pxm_tile_y << 1
        wfm_tile_data = (wfm_tile_y << 4) | wfm_tile_x
        wfmo.write(bytes([wfm_tile_data]))


def convert_npcs(name: str, pxei: typing.BinaryIO, wfeo: typing.TextIO):
    pxe_data = pxei.read()  # map tile data
    assert pxe_data[:4] == b"PXE\x00", "header doesn't match PXE\\x00"

    ent_count = struct.unpack("<I", pxe_data[4:8])[0]
    assert ent_count <= 32, "must be less than or equal to 32 entities in map"

    ent_data: list[WaffleEntity] = []
    rp = 8
    for _ in range(ent_count):
        ent_x = struct.unpack("<H", pxe_data[rp : rp + 2])[0]
        ent_y = struct.unpack("<H", pxe_data[rp + 2 : rp + 4])[0]
        ent_flagid = struct.unpack("<H", pxe_data[rp + 4 : rp + 6])[0]  # unused for now
        ent_event = struct.unpack("<H", pxe_data[rp + 6 : rp + 8])[0]
        ent_type = struct.unpack("<H", pxe_data[rp + 8 : rp + 10])[0]
        ent_flags = struct.unpack("<H", pxe_data[rp + 10 : rp + 12])[0]
        rp += 12

        went = WaffleEntity()
        went.x = ent_x
        went.y = ent_y
        if ent_event == 0:
            went.ascptr = "Asc_None"
        else:
            went.ascptr = f"Asc_{name}_{ent_event:04d}"

        assert ent_type in CS_TO_WAFFLE_ENT, f"unknown entity {ent_type} found in map"
        went.enttype = CS_TO_WAFFLE_ENT[ent_type]
        went.flags = 0
        if (ent_flags & 0x1000) != 0:  # spawn with alt direction
            went.flags |= 0x80
        if (ent_flags & 0x0400) != 0:  # unused (for running on map load)
            went.flags |= 0x40
        if (ent_flags & 0x2000) != 0:  # interactable
            went.flags |= 0x20

        ent_data.append(went)

    wfeo.write("; DP region ;;;;;;;;;;;;;;;;;;;;;\n")
    wfeo.write("; nx .res (TNpcDataMax*2)\n")
    wfeo.write("    .word ")
    for i in range(32):
        if i < ent_count:
            wfeo.write(f"({ent_data[i].x}*16+8)")
        else:
            wfeo.write("0")

        if i != 31:
            wfeo.write(", ")
        else:
            wfeo.write("\n")

    wfeo.write("; ny .res (TNpcDataMax*2)\n")
    wfeo.write("    .word ")
    for i in range(32):
        if i < ent_count:
            wfeo.write(f"({ent_data[i].y}*16+8)")
        else:
            wfeo.write("0")

        if i != 31:
            wfeo.write(", ")
        else:
            wfeo.write("\n")

    wfeo.write(
        "; nframe .res (TNpcDataMax*2) ; increments once every frame, 0 at npc spawn\n"
    )
    wfeo.write("    .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, ")
    wfeo.write("0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0\n")

    wfeo.write("; nidx .res (TNpcDataMax*1) ; npc index\n")
    wfeo.write("    .byte ")
    for i in range(32):
        if i < ent_count:
            wfeo.write(ent_data[i].enttype)
        else:
            wfeo.write("0")

        if i != 31:
            wfeo.write(", ")
        else:
            wfeo.write("\n")

    wfeo.write("; flags .res (TNpcDataMax*1) ; see TNpcDataFl###\n")
    wfeo.write("    .byte ")
    for i in range(32):
        if i < ent_count:
            wfeo.write(f"${ent_data[i].flags:02x}")
        else:
            wfeo.write("0")

        if i != 31:
            wfeo.write(", ")
        else:
            wfeo.write("\n")

    wfeo.write("; non-DP region ;;;;;;;;;;;;;;;;;\n")
    wfeo.write("; nascptr .res (TNpcDataMax*2)  ; npc current asm address\n")
    wfeo.write("    .word ")
    for i in range(32):
        if i < ent_count:
            wfeo.write(f".loword({ent_data[i].ascptr})")
        else:
            wfeo.write("0")

        if i != 31:
            wfeo.write(", ")
        else:
            wfeo.write("\n")

    # same as nascptr
    wfeo.write("; nascptrs .res (TNpcDataMax*2) ; npc start asm address\n")
    wfeo.write("    .word ")
    for i in range(32):
        if i < ent_count:
            wfeo.write(f".loword({ent_data[i].ascptr})")
        else:
            wfeo.write("0")

        if i != 31:
            wfeo.write(", ")
        else:
            wfeo.write("\n")

    wfeo.write("; ndata0 .res (TNpcDataMax*2) ; free data space\n")
    wfeo.write("    .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, ")
    wfeo.write("0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0\n")
    wfeo.write("; ndata1 .res (TNpcDataMax*2) ; ...\n")
    wfeo.write("    .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, ")
    wfeo.write("0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0\n")
    wfeo.write("; ndata2 .res (TNpcDataMax*1) ; ...\n")
    wfeo.write("    .byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, ")
    wfeo.write("0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0\n")
    wfeo.write("; ndata3 .res (TNpcDataMax*1) ; ...\n")
    wfeo.write("    .byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, ")
    wfeo.write("0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0\n")


def convert_script(
    name: str, tsci: typing.BinaryIO, asco: typing.TextIO, asao: typing.TextIO
):
    tsc_data = tsci.read()
    mid_byte_idx = len(tsc_data) // 2
    sub_byte = tsc_data[mid_byte_idx]
    dec_scr = ""
    for i in range(len(tsc_data)):
        if i != mid_byte_idx:
            dec_scr += chr(tsc_data[i] - sub_byte)
        else:
            dec_scr += chr(tsc_data[i])

    asco.write(f'.include "{name}_asc.inc"\n\n')

    dec_scr_lines = dec_scr.splitlines()
    cur_msg = None
    cur_fn = None
    asc_name = "Asc_unk"
    for line in dec_scr_lines:
        if line.startswith("#"):
            if cur_fn is not None:
                asco.write("\n    AscReset\n")
                asco.write(".endproc\n\n")

            try:
                cur_fn = int(line[1:5])
            except:
                assert False, "script function index should have been in format #1234"

            asc_name = f"Asc_{name}_{cur_fn:04d}" if cur_fn else "Asc_unk"

            asco.write(f".proc {asc_name}\n")
            asco.write("    AscAddr .set 0\n")
            asco.write("    AscInit\n\n")

            asao.write(f".global {asc_name}\n")

            cur_msg = None
        else:
            line_strip = line.strip()
            if len(line_strip) == 0:
                continue

            asco.write(f"    ; {line_strip}\n")
            i = 0
            while i < len(line):
                c = line[i]
                if c != "<":
                    if cur_msg is not None:
                        if c != "\r":
                            cur_msg += c

                    i += 1
                    continue

                if cur_msg is not None and cur_msg != "":
                    # remove newline at beginning if one exists
                    if len(cur_msg) > 0 and cur_msg[0] == "\n":
                        cur_msg = cur_msg[1:]

                    # fix line newlines
                    msg_lines = cur_msg.splitlines()

                    cur_msg = ""
                    for l in msg_lines:
                        assert (
                            len(l) <= 30
                        ), f"msg line {l} too long, pls make shorter thx :)"
                        cur_msg += f"{l:<30}"

                    cur_msg = cur_msg.rstrip()  # remove padding at end

                    if (len(cur_msg) % 2) == 1:
                        cur_msg += " "

                    asco.write(f"    AscMsg {asc_name}, {len(cur_msg)}\n")
                    for j in range(0, len(cur_msg), 2):
                        schr_a = cur_msg[j]
                        schr_b = cur_msg[j + 1]
                        assert (
                            schr_a in TEXT_TO_WAFFLE_TXT
                            and schr_b in TEXT_TO_WAFFLE_TXT
                        ), f"invalid char (must be in {TEXT_TO_WAFFLE_TXT})"

                        chr_a = TEXT_TO_WAFFLE_TXT.index(schr_a)
                        chr_b = TEXT_TO_WAFFLE_TXT.index(schr_b)
                        asco.write(
                            f"    AscMsgChar {asc_name}, {chr_a}, {chr_b}, {j}\n"
                        )

                    cur_msg = ""

                cmd = line[i + 1 : i + 4]
                arg_count = 0
                match cmd:
                    case "END":
                        cur_msg = None
                        arg_count = 0
                    case "FAI" | "FAO":
                        arg_count = 1
                    case "FLJ":
                        arg_count = 2
                    case "FL+":
                        cmd = "FLP"
                        arg_count = 1
                    case "MOV":
                        arg_count = 2
                    case "NOD":
                        arg_count = 0
                    case "PRI":
                        arg_count = 0
                    case "STC":  # hack to reset interactive flag
                        arg_count = 0
                    case "TRA":
                        arg_count = 4
                    case "WAI":
                        arg_count = 1
                    # ###
                    case "MSG":
                        cur_msg = ""
                        arg_count = 0
                    case _:
                        assert False, f"don't know tsc command {cmd} yet (line {line})"

                arg_values: list[str | int] = [asc_name]
                for j in range(arg_count):
                    try:
                        read_idx = i + 4 + j * 5
                        arg_values.append(int(line[read_idx : read_idx + 4]))
                    except:
                        assert False, "script should be in format <CMDXXXX:...."

                if cmd != "MSG":
                    if cmd == "FLJ":
                        asco.write(
                            f"    Asc{cmd} {arg_values[0]}, {arg_values[1]}, Asc{name}_{arg_values[2]:04d}\n"
                        )
                    else:
                        asco.write(f"    Asc{cmd} {', '.join(map(str, arg_values))}\n")

                i += 4  # for <XYZ
                if arg_count > 0:
                    i += (arg_count * 5) - 1  # - 1 for the last : in the arg list

            if cur_msg is not None:
                cur_msg += "\n"

    if cur_fn is not None:
        asco.write("\n    AscReset\n")
        asco.write(".endproc\n\n")


def run(inp_level_prefix: str, out_wfm: str):
    level_name = os.path.basename(inp_level_prefix)

    # convert tiles
    if True:
        pxmi = open(inp_level_prefix + ".pxm", "rb")
        # pxai = open(inp_level_pxa, "rb")
        wfmo = open(out_wfm + ".wfm", "wb")

        convert_tiles(pxmi, wfmo)

        wfmo.close()
        # pxai.close()
        pxmi.close()

    # convert npcs (since we use function pointers,
    # this must be written as assembly separately)
    if True:
        pxei = open(inp_level_prefix + ".pxe", "rb")
        wfeo = open(out_wfm + "_wfe.asm", "w")

        convert_npcs(level_name, pxei, wfeo)

        wfeo.close()
        pxei.close()

    # convert tsc
    if True:
        tsci = open(inp_level_prefix + ".tsc", "rb")
        asco = open(out_wfm + "_asc.asm", "w")
        asao = open(out_wfm + "_asc.inc", "w")

        convert_script(level_name, tsci, asco, asao)

        asco.close()
        tsci.close()


def main(args: list[str]):
    if len(args) < 3:
        print("mapconv [input level prefix] [output wfm name]")
        return
    # if len(args) < 4:
    #     print("mapconv [input level prefix] [input pxa file] [output wfm name]")
    #     return

    inp_level_prefix = sys.argv[1]
    # inp_level_pxa = sys.argv[2]
    out_wfm = sys.argv[2]

    logging.info(f"working on level {out_wfm}")
    run(inp_level_prefix, out_wfm)


if __name__ == "__main__":
    from colorlog import setup_logging

    setup_logging()

    main(sys.argv)
