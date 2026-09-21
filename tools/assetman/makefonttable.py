import logging
import sys
from PIL import Image


def run(inp_path: str, inp_chr_path: str, var_name: str, out_path: str) -> bool:
    char_list: str
    with open(inp_chr_path, "r") as f:
        char_list = f.read().strip()

    out_strm = open(out_path, "w")

    im = Image.open(inp_path)
    pix = im.load()
    if pix is None:
        logging.error("couldn't load image")
        return False

    chars: dict[str, list[int]] = {}
    cur_char_idx = 0
    cur_char_width = 0
    for px in range(im.width):
        new_char = True
        for py in range(im.height):
            v = pix[px, py]
            if v != 0:
                new_char = False
                break  # still building this char

        if new_char:
            cur_char_idx += 1
            cur_char_width = 0
            # if px < im.width - 1:
            #     logging.info(f"new char {char_list[cur_char_idx]} at {px}")
            continue

        cur_char_width += 1
        if cur_char_width > 8:
            logging.error(
                f"char {char_list[cur_char_idx]} is longer than 8 pixels wide"
            )
            return False

        for py in range(im.height):
            v = pix[px, py]
            vb = 1 if v == 1 else 0
            k = char_list[cur_char_idx]
            if k not in chars:
                chars[k] = []

            chars[k].append(vb)

    chars[" "] = [0] * 12

    out_strm.write(var_name + "_Widths:\n")
    for c in chars:
        cl = chars[c]
        c_width = len(cl) // im.height
        out_strm.write(f"  .byte {c_width} ; {c}\n")

    out_strm.write("\n" + var_name + "_Strips:\n")
    for c in chars:
        cl = chars[c]
        c_width = len(cl) // im.height
        row_list = []
        for py in range(1, im.height):
            row_val = 0
            row_bit = 7
            for px in range(c_width):
                if cl[px * im.height + py] != 0:
                    row_val |= 1 << row_bit

                row_bit -= 1

            row_list.append(row_val)

        while len(row_list) < 8:
            row_list.append(0)

        out_strm.write(
            f"  .byte {', '.join(['$' + hex(x)[2:].zfill(2) for x in row_list])} ; {c}\n"
        )

    out_strm.close()
    return True


def main(args: list[str]):
    if len(args) < 5:
        print(f"{args[0]} [input image] [input txt] [var name] [output asm]")
        return

    inp_path = args[0]
    inp_chr_path = args[1]
    var_name = args[2]
    out_path = args[3]

    run(inp_path, inp_chr_path, var_name, out_path)


if __name__ == "__main__":
    from colorlog import setup_logging

    setup_logging()

    main(sys.argv)
