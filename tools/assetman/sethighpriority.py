import sys

# quick 30 second fix for superfamiconv
# not having any option to set high pri
# todo: this is not the case anymore
# with the --in-attribute-map flag


def set_high_prio(path: str):
    f = open(path, "rb")
    d = bytearray(f.read())
    f.close()

    i = 0
    while i < len(d):
        d[i + 1] |= 0x20
        i += 2

    fo = open(path, "wb")
    fo.write(d)
    fo.close()


def main(args: list[str]):
    if len(args) < 2:
        return

    set_high_prio(args[1])


if __name__ == "__main__":
    main(sys.argv)
