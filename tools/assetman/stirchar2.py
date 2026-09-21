import sys
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from ortools.sat.python import cp_model
import hashlib

import logging

# todo: code was written by claude and really needs to be rewritten.
# this code went over quite a bit of iteration, so it's doing a lot of
# things that aren't really necessary anymore. the main purpose of this
# is to optimize character sprites in VN mode such that three characters
# can be on the screen at a time without issues. I have tested various
# character sprites and have confirmed that without compromising on
# character designs, there is no way to fit in full characters into
# sprites' VRAM data. this script has two purposes in order to fix that:
# - find optimial solutions that cut out unused pixels while not using
#   so many sprites that we exhaust them all.
# - split character sprites into thirds (vertically ordered, so "top",
#   "middle", "bottom") so we can swap from top/middle to middle/bottom
#   using HDMA at some point in the middle of the screen.
#
# if the character sprites were not moving vetically, it would be good
# enough to swap everyone's top/middle to bottom at the same time.
# however, since I want to leave open the possibility of sprites having
# different Y positions from each other, the only way to get that to
# work is by keeping the middle third in the second sprite VRAM chunk.
#
# currently we are fixed at 80x192 because this was the size of the
# test sprite I was working on and anything wider than that x3 would be
# too much for the screen. what I didn't think of until later is a single
# wide character sprite, which currently isn't supported but could be in
# the future without much hassle. for now, 80x192 sizes are required.
# ---
# limitations I've arbitrarily chosen
# - tiles must be made up of either 16x16 or 32x32 tiles
# - max 32x32 tiles: 12 (8 between top/middle, 8 between middle/bottom)
# - max 16x16 tiles: 8 (across all halves), although I would prefer 6 at most
# - tiles must snap to a 8x8 grid, regardless of tile size
# - tiles can't cross a third boundary


# 8x8 grid. we're using sprites so we're not limited to 8x8 BG tile positions,
# but this simplifies things a little bit so we'll go with it.
# to be clear, we're calling:
# - a cell an 8x8 region
# - a tile a 16x16 or 32x32 region
GRID_SIZE = 8
CHARACTER_WIDTH = 80
CHARACTER_HEIGHT = 192
MAX_SPRITES = 25  # should be plenty?
TILE_SIZE_SMALL = 16
TILE_SIZE_LARGE = 32
TILE_SIZES = [TILE_SIZE_SMALL // GRID_SIZE, TILE_SIZE_LARGE // GRID_SIZE]

THIRD_HEIGHT_PX = CHARACTER_HEIGHT // 3
THIRD_HEIGHT_CELLS = THIRD_HEIGHT_PX // GRID_SIZE
THIRD_NAMES = ["top", "middle", "bottom"]
THIRD_TILE_BASE = [0x80, 0xC0, 0x80]


# an individual placement for a tile
@dataclass
class Placement:
    x: int  # top left corner
    y: int  # ...
    cell_size: int  # 2 for 16x16 and 4 for 32x32
    tile_id: int  # id used by UniqueTile (below)

    def cells(self):
        for yoff in range(self.cell_size):
            for xoff in range(self.cell_size):
                yield (self.y + yoff, self.x + xoff)

    def third(self) -> int:
        # which of the 1/3 high regions this placement is in
        return self.y // THIRD_HEIGHT_CELLS

    def vram_tile_off(self) -> int:
        # get the offset from this strip's start position
        return self.tile_id * self.cell_size


# unique tile, used after the tile placement opto algo runs
@dataclass
class UniqueTile:
    src_x: int
    src_y: int
    size_cells: int
    tile_id: int
    image: Image.Image


def load_image_data(img: Image.Image) -> tuple[np.ndarray, np.ndarray] | None:
    arr = np.array(img)
    height, width = arr.shape

    # should we be less strict on input size in the future?
    if width != CHARACTER_WIDTH or height != CHARACTER_HEIGHT:
        logging.error(
            "Expected image size %dx%d, found %dx%d",
            CHARACTER_WIDTH,
            CHARACTER_HEIGHT,
            width,
            height,
        )
        return None

    cell_width = width // GRID_SIZE
    cell_height = height // GRID_SIZE

    # array to test whether there is a solid pixel here or not
    mask = np.zeros((cell_height, cell_width), dtype=bool)
    # array to test the "uniqueness" of a tile
    # as much as it feels wrong, we are going to put the _entire_
    # array for a cell's pixels into each item in the grid. python
    # is okay with checking if two large arrays are the same.
    data_grid = np.empty((cell_height, cell_width), dtype=object)

    for y in range(cell_height):
        for x in range(cell_width):
            # fmt: off
            cell = arr[
                y * GRID_SIZE : (y + 1) * GRID_SIZE,
                x * GRID_SIZE : (x + 1) * GRID_SIZE
            ]
            # fmt: on
            mask[y, x] = bool(np.any(cell != 0))
            data_grid[y, x] = cell.tobytes()

    return mask, data_grid


def run_solver(
    mask: np.ndarray, data_grid: np.ndarray, max_sprites=25
) -> list[Placement] | None:
    # in cells, not pixels
    height, width = mask.shape

    large_cell_size = TILE_SIZES[1]

    candidates: list[Placement] = []
    for size in TILE_SIZES:
        for y in range(height - size + 1):
            # prevent a tile from crossing a 1/3 height boundary
            top_third = y // THIRD_HEIGHT_CELLS
            bottom_third = (y + size - 1) // THIRD_HEIGHT_CELLS
            if top_third != bottom_third:
                continue

            for x in range(width - size + 1):
                p = Placement(x, y, size, -1)
                # skip if pixels are empty
                if any(mask[cy, cx] for cy, cx in p.cells()):
                    candidates.append(p)

    model = cp_model.CpModel()
    solver = cp_model.CpSolver()

    p_vars = [model.new_bool_var(f"p{i}") for i in range(len(candidates))]

    # setup some basic constraints that work regardless of optos
    cell_to_p_indices: dict[tuple[int, int], list[int]] = {}
    for y in range(height):
        for x in range(width):
            cell_to_p_indices[(y, x)] = []

    for i, p in enumerate(candidates):
        for cell in p.cells():
            cell_to_p_indices[cell].append(i)

    for y in range(height):
        for x in range(width):
            p_indices = cell_to_p_indices[(y, x)]
            if mask[y, x]:
                # cell must be covered at least once
                model.add(sum(p_vars[i] for i in p_indices) == 1)
            elif len(p_indices) > 0:
                # cell could be covered at least once if needed
                model.add(sum(p_vars[i] for i in p_indices) <= 1)

    if max_sprites is not None:
        model.add(sum(p_vars) <= max_sprites)

    # try to optimize both a smaller number of sprites but also not
    # just try to slap 32x32 everywhere...

    block_group_to_p_vars: dict[tuple, set[int]] = {}

    for i, p in enumerate(candidates):
        # piece together a tile based on smaller cells
        whole = b"".join(data_grid[cy, cx] for cy, cx in p.cells())
        if p.cell_size == large_cell_size:
            key = (p.cell_size, p.third(), whole)
        else:
            key = (p.cell_size, whole)

        block_group_to_p_vars.setdefault(key, set()).add(i)

    b_vars = {
        k: model.new_bool_var(f"b{idx}") for idx, k in enumerate(block_group_to_p_vars)
    }
    for k, cand_indices in block_group_to_p_vars.items():
        for i in cand_indices:
            model.add(p_vars[i] <= b_vars[k])

    large_b_vars_by_third: dict[int, list] = {t: [] for t in range(3)}
    for k, b_var in b_vars.items():
        if k[0] == large_cell_size:
            large_b_vars_by_third[k[1]].append(b_var)

    # limit 4 32x32s per third (probably not necessary but may help with bugs/performance?)
    for group_vars in large_b_vars_by_third.values():
        if group_vars:
            model.add(sum(group_vars) <= 4)

    tile_cost = sum(b_vars[k] * k[0] ** 2 for k in b_vars)
    model.minimize(tile_cost * 1000 + sum(p_vars))

    status = solver.solve(model)
    success = status == cp_model.OPTIMAL or status == cp_model.FEASIBLE
    if not success:
        logging.error("Failed to solve? Status was %s", solver.status_name(status))
        return None

    answer = [candidates[i] for i in range(len(candidates)) if solver.Value(p_vars[i])]
    return answer


def write_debug_image(
    mask: np.ndarray, data_grid: np.ndarray, placements: list[Placement], out_path: str
):
    SCALE = 10

    height, width = mask.shape
    img = Image.new("RGB", (width * SCALE, height * SCALE), "white")
    draw = ImageDraw.Draw(img)

    def uniq_color(sig):
        hbytes = hashlib.md5(sig).digest()
        return (100 + hbytes[0] % 156, 100 + hbytes[1] % 156, 100 + hbytes[2] % 156)

    for y in range(height):
        for x in range(width):
            if mask[y, x]:
                draw.rectangle(
                    [x * SCALE, y * SCALE, (x + 1) * SCALE - 1, (y + 1) * SCALE - 1],
                    fill=uniq_color(data_grid[y, x]),
                )

    size_outline = {
        1: (230, 90, 130),  # 8x8 (not supported anymore since it's a waste of sprites)
        2: (80, 170, 240),  # 16x16
        4: (80, 230, 100),  # 32x32
    }
    for p in placements:
        x0, y0 = p.x * SCALE, p.y * SCALE
        x1, y1 = x0 + p.cell_size * SCALE, y0 + p.cell_size * SCALE
        draw.rectangle(
            [x0, y0, x1 - 1, y1 - 1],
            outline=size_outline.get(p.cell_size, "black"),
            width=2,
        )

    # draw third boundaries
    for i in range(1, 3):
        y = i * THIRD_HEIGHT_CELLS * SCALE
        draw.line([(0, y), (width * SCALE, y)], fill=(0, 0, 0), width=2)

    img.save(out_path)


def write_output_files(
    out_path: str,
    var_name: str,
    img: Image.Image,
    placements: list[Placement],
):
    # we could use data_grid again to get tile uniqueness maybe?
    # but we already want to create png tiles so it doesn't really matter

    small_placements: list[Placement] = []
    large_placements_by_third: dict[int, list[Placement]] = {t: [] for t in range(3)}

    small_tiles: dict[bytes, UniqueTile] = {}
    large_tiles_by_third: dict[int, dict[bytes, UniqueTile]] = {t: {} for t in range(3)}

    small_tile_id = 0
    large_tile_id_by_third = {t: 0 for t in range(3)}

    for placement in placements:
        placement_size_px = placement.cell_size * GRID_SIZE
        if placement_size_px == TILE_SIZE_SMALL:
            small_placements.append(placement)

            src_x = placement.x * GRID_SIZE
            src_y = placement.y * GRID_SIZE
            region = img.crop(
                (src_x, src_y, src_x + TILE_SIZE_SMALL, src_y + TILE_SIZE_SMALL)
            )
            region_bytes = region.tobytes()

            if region_bytes not in small_tiles:
                small_tiles[region_bytes] = UniqueTile(
                    src_x, src_y, placement.cell_size, small_tile_id, region
                )
                small_tile_id += 1

            placement.tile_id = small_tiles[region_bytes].tile_id

        elif placement_size_px == TILE_SIZE_LARGE:
            third = placement.third()
            large_placements_by_third[third].append(placement)

            src_x = placement.x * GRID_SIZE
            src_y = placement.y * GRID_SIZE
            region = img.crop(
                (src_x, src_y, src_x + TILE_SIZE_LARGE, src_y + TILE_SIZE_LARGE)
            )
            region_bytes = region.tobytes()

            tiles_this_third = large_tiles_by_third[third]
            if region_bytes not in tiles_this_third:
                tiles_this_third[region_bytes] = UniqueTile(
                    src_x,
                    src_y,
                    placement.cell_size,
                    large_tile_id_by_third[third],
                    region,
                )
                large_tile_id_by_third[third] += 1

            placement.tile_id = tiles_this_third[region_bytes].tile_id

        else:
            assert False, "no way this can happen"

    # small strip
    small_tiles_list = sorted(small_tiles.values(), key=lambda t: t.tile_id)
    small_dims = (max(len(small_tiles_list), 1) * TILE_SIZE_SMALL, TILE_SIZE_SMALL)
    small_out = img.resize(small_dims)  # cloning image so we keep the same palette
    small_out.paste(0, (0, 0, small_dims[0], small_dims[1]))
    for i, tile in enumerate(small_tiles_list):
        small_out.paste(tile.image, (i * TILE_SIZE_SMALL, 0))

    small_out.save(out_path + "_all_small.png")

    # three large strips
    for third in range(3):
        tiles_list = sorted(
            large_tiles_by_third[third].values(), key=lambda t: t.tile_id
        )

        dims = (4 * TILE_SIZE_LARGE, TILE_SIZE_LARGE)
        large_out = img.resize(dims)  # ditto on palette
        large_out.paste(0, (0, 0, dims[0], dims[1]))
        for i, tile in enumerate(tiles_list):
            large_out.paste(tile.image, (i * TILE_SIZE_LARGE, 0))

        large_out.save(f"{out_path}_{THIRD_NAMES[third]}_large.png")

    # write out instances
    byte_count = 0  # we need to be aligned to 8 bytes by the end
    with open(out_path + "_meta.asm", "w") as info_file:
        info_file.write(f"{var_name}:\n")

        info_file.write("  ; small tiles\n")
        for placement in small_placements:
            x = placement.x * GRID_SIZE
            y = placement.y * GRID_SIZE
            info_file.write(f"  .byte {x}, {y}, {placement.vram_tile_off()}\n")
            byte_count += 3

        for third in range(3):
            base = THIRD_TILE_BASE[third]
            info_file.write(f"\n  ; {THIRD_NAMES[third]} third large tiles\n")
            ordered = sorted(large_placements_by_third[third], key=lambda p: (p.y, p.x))
            for placement in ordered:
                x = placement.x * GRID_SIZE
                y = placement.y * GRID_SIZE
                tile_id = placement.vram_tile_off() + base
                info_file.write(f"  .byte {x}, {y}, {tile_id}\n")
                byte_count += 3

        info_file.write("\n  .byte 255, 255, 255 ; sentinel\n")
        byte_count += 3

        if (byte_count % 8) > 0:
            align = 8 - (byte_count % 8)
            info_file.write(f"  .byte {', '.join(['0'] * align)} ; padding\n")
        else:
            info_file.write(f"  ; no padding created :D\n")


def run(image_path: str, output_path: str, var_name: str) -> bool:
    img = Image.open(image_path)
    if img.mode != "P":
        logging.error("Image isn't in palette mode?")
        return False

    image_data_opt = load_image_data(img)
    if image_data_opt is None:
        return False

    mask, data_grid = image_data_opt
    answer_opt = run_solver(mask, data_grid, MAX_SPRITES)
    if answer_opt is None:
        return False

    answer = answer_opt
    write_debug_image(
        mask, data_grid, answer, str(Path(image_path).with_suffix(".dbg.png"))
    )
    write_output_files(output_path, var_name, img, answer)

    return True


def main(args: list[str]):
    if len(args) < 4:
        print(f"{args[0]} [input_path] [output_path] [var_name]")
        return

    logging.info(f"working on character {args[3]}")
    run(args[1], args[2], args[3])


if __name__ == "__main__":
    from colorlog import setup_logging

    setup_logging()

    main(sys.argv)
