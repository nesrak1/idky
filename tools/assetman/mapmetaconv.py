import logging
import sys

# pxa tile collision conversion
PXA_TO_WFT = {
    0x00: 0x00,  # background/empty
    0x40: 0x01,  # foreground/empty
    0x41: 0x80,  # foreground/solid
    0x50: 0xC0,  # slope rsll/solid
    0x51: 0xC1,  # slope rslh/solid
    0x52: 0xC2,  # slope rsrh/solid
    0x53: 0xC3,  # slope rsrl/solid
    0x54: 0xC4,  # slope fslh/solid
    0x55: 0xC5,  # slope fsll/solid
    0x56: 0xC6,  # slope fsrl/solid
    0x57: 0xC7,  # slope fsrh/solid
}


def run(inp_level_pxa: str, out_wft: str):
    pxai = open(inp_level_pxa, "rb")
    wfmo = open(out_wft, "wb")

    for y in range(8):
        for x in range(8):
            pxa_val = pxai.read(1)[0]
            conv_val = PXA_TO_WFT[pxa_val]
            wfmo.write(bytes([conv_val]))

        pxai.read(8)  # skip 8 bytes of padding we don't support
        wfmo.write(bytes([0, 0, 0, 0, 0, 0, 0, 0]))  # unused and only exist as an opto

    wfmo.close()
    pxai.close()


def main(args: list[str]):
    if len(args) < 3:
        print("mapmetaconv [input pxa file] [output wft]")
        print("warning: assuming tileset is exactly 8x8 sized!")
        return

    inp_level_pxa = sys.argv[2]
    out_wft = sys.argv[2]

    logging.info(f"working on tile metadata {out_wft}")
    run(inp_level_pxa, out_wft)


if __name__ == "__main__":
    from colorlog import setup_logging

    setup_logging()

    main(sys.argv)
