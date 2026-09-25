import logging
from pathlib import Path
import platform
from runpy import run_path
import shutil
import subprocess
import sys
import typing

from stirchar2 import run as run_stirchar2
from makefonttable import run as run_makefonttable
from mapconv import run as run_mapconv
from mapmetaconv import run as run_mapmetaconv
from sethighpriority import set_high_prio

# assetman: main asset management tool


# ###################


class CharacterVariant:
    def __init__(self, variant_entry: typing.Any):
        # the variant name
        self.name = typing.cast(str, variant_entry["name"])
        # the image to use
        self.image = typing.cast(str, variant_entry["image"])


class CharacterEntry:
    def __init__(self, char_entry: typing.Any):
        # the character's display name (also used for assetgen naming)
        self.name = typing.cast(str, char_entry["name"])
        # the prefix to use (what to call this from assembly)
        self.prefix = typing.cast(str, char_entry["prefix"])
        # the bank name to place this data in
        self.bank = typing.cast(str, char_entry["bank"])
        # the character's internal id
        self.charid = typing.cast(int, char_entry["charid"])
        # the image variant list (the different poses for this character)
        self.variants = [CharacterVariant(cv) for cv in char_entry["variants"]]


class BackgroundEntry:
    def __init__(self, bg_entry: typing.Any):
        self.name = typing.cast(str, bg_entry["name"])
        self.prefix = typing.cast(str, bg_entry["prefix"])
        self.bank = typing.cast(str, bg_entry["bank"])
        self.bgid = typing.cast(int, bg_entry["bgid"])
        self.image = typing.cast(str, bg_entry["image"])
        self.prio = typing.cast(bool, bg_entry["prio"])

        self.args: dict[str, str] = {}
        if "args" in bg_entry:
            self.args = typing.cast(dict[str, str], bg_entry["args"])


class TilesetEntry:
    def __init__(self, bg_entry: typing.Any):
        self.name = typing.cast(str, bg_entry["name"])
        self.prefix = typing.cast(str, bg_entry["prefix"])
        self.bank = typing.cast(str, bg_entry["bank"])
        self.tsid = typing.cast(int, bg_entry["tsid"])
        self.image = typing.cast(str, bg_entry["image"])
        # tile attributes, used to describe the collision shape of tiles on the tileset
        self.attr = typing.cast(str, bg_entry["attr"])

        self.args: dict[str, str] = {}
        if "args" in bg_entry:
            self.args = typing.cast(dict[str, str], bg_entry["args"])


class WorldEntry:
    def __init__(self, bg_entry: typing.Any):
        self.name = typing.cast(str, bg_entry["name"])
        self.prefix = typing.cast(str, bg_entry["prefix"])
        self.bank = typing.cast(str, bg_entry["bank"])
        self.lvid = typing.cast(int, bg_entry["lvid"])
        self.map = typing.cast(str, bg_entry["map"])
        self.tileset = typing.cast(str, bg_entry["tileset"])


class EntityEntry:
    def __init__(self, ent_entry: typing.Any):
        # the entity's display name (also used for assetgen naming)
        self.name = typing.cast(str, ent_entry["name"])
        # the prefix to use (what to call this from assembly)
        self.prefix = typing.cast(str, ent_entry["prefix"])
        # the bank name to place this data in
        self.bank = typing.cast(str, ent_entry["bank"])
        # the image (16*n by 16 pixels, each frame side by side)
        self.image = typing.cast(str, ent_entry["image"])

        self.args: dict[str, str] = {}
        if "args" in ent_entry:
            self.args = typing.cast(dict[str, str], ent_entry["args"])


class UiEntry:
    def __init__(self, ui_entry: typing.Any):
        self.name = typing.cast(str, ui_entry["name"])
        self.type = typing.cast(str, ui_entry["type"])
        self.prefix = typing.cast(str, ui_entry["prefix"])
        self.bank = typing.cast(str, ui_entry["bank"])

        self.image: str | None = None
        self.prio: bool | None = None
        self.data: list[int] | None = None
        if self.type == "image":
            self.image = typing.cast(str, ui_entry["image"])
            self.prio = typing.cast(bool, ui_entry["prio"])
        elif self.type == "palette":
            self.data = typing.cast(list[int], ui_entry["data"])

        self.args: dict[str, str] = {}
        if "args" in ui_entry:
            self.args = typing.cast(dict[str, str], ui_entry["args"])


class FontEntry:
    def __init__(self, font_entry: typing.Any):
        self.name = typing.cast(str, font_entry["name"])
        self.prefix = typing.cast(str, font_entry["prefix"])
        self.bank = typing.cast(str, font_entry["bank"])
        self.image = typing.cast(str, font_entry["image"])
        self.mapping = typing.cast(str, font_entry["mapping"])


# ###################


# delete the folder contents without deleting the entire folder
# your sitting-in-assetgen terminal will thank you :)
def delete_folder_contents(path: Path):
    for item in path.iterdir():
        if item.is_dir():
            shutil.rmtree(item)
        else:
            item.unlink()


# ###################


def run_superfamiconv(tools_path: Path, args: dict[str, str]) -> bool:
    superfamiconv_path: Path
    plat = platform.system()
    if plat == "Linux":
        superfamiconv_path = tools_path / "superfamiconv"
    elif plat == "Windows":
        superfamiconv_path = tools_path / "superfamiconv.exe"
    else:
        superfamiconv_str_path = shutil.which("superfamiconv")
        if superfamiconv_str_path is None:
            raise Exception("Only Windows/Linux supported for superfamiconv for now")

        superfamiconv_path = Path(superfamiconv_str_path)

    args_arr: list[str] = [str(superfamiconv_path), "convert"]
    for key in args:
        args_arr.append(key)

        value = args[key]
        if value != "":
            args_arr.append(args[key])

    try:
        subprocess.run(args_arr)
    except subprocess.CalledProcessError as e:
        logging.error("superfamiconv returned an error, exiting now")
        return False

    return True


# ###################


class AssetManager:
    def __init__(self, assets_path: Path, assetgen_path: Path, tools_path: Path):
        # the bank to place the directory tables in
        self.char_table_bank = "CODE"
        self.world_table_bank = "CODE"
        self.entity_table_bank = "CODE"

        self.lines: list[str] = []
        self.inc_lines: list[str] = []
        self.assets_path = assets_path
        self.assetgen_path = assetgen_path
        self.tools_path = tools_path

        self.start_lines()

    def add_header(self, header: str):
        # todo: standardize header comment lengths
        # I'm a bit inconsistent in this project :sweat_smile:
        comment_str = "; " + header + " " + (";" * (66 - len(header)))
        self.lines.append("")
        self.lines.append(comment_str)
        self.lines.append("")

    def add_segment(self, segment: str):
        self.lines.append('.segment "' + segment + '"')
        self.lines.append("")

    def add_label(self, label: str, inc_only=False):
        if not inc_only:
            self.lines.append(label + ":")

        self.inc_lines.append(".global " + label)

    def add_include(self, path: Path, binary: bool):
        path_fixed = str(path.relative_to(self.assetgen_path)).replace("\\", "/")
        if binary:
            self.lines.append('.incbin "' + path_fixed + '"')
        else:
            self.lines.append('.include "' + path_fixed + '"')

    def start_lines(self):
        self.lines.append(".p816")
        self.lines.append(".i16")
        self.lines.append(".a8")
        self.lines.append('.include "all_assets.inc"')
        self.lines.append('.include "pf_asc.inc"')
        self.lines.append('.include "pf_asc_macros.inc"')
        self.lines.append('.include "pf_npc.inc"')
        self.lines.append('.include "variables.inc"')
        self.inc_lines.append(".ifndef ALL_ASSETS_INC")
        self.inc_lines.append("ALL_ASSETS_INC = 1")
        self.inc_lines.append("")

    def end_lines(self):
        self.inc_lines.append("")
        self.inc_lines.append(".endif ; ALL_ASSETS_INC")

    def write_lines(self):
        with open(self.assetgen_path / "all_assets.s", "w") as fo:
            for line in self.lines:
                fo.write(line + "\n")

        with open(self.assetgen_path / "all_assets.inc", "w") as fo:
            for line in self.inc_lines:
                fo.write(line + "\n")

    def process_metadata(self, metadata: typing.Any) -> bool:
        if "charbank" in metadata:
            self.char_table_bank = metadata["charbank"]
        if "worldbank" in metadata:
            self.world_table_bank = metadata["worldbank"]
        if "entitybank" in metadata:
            self.entity_table_bank = metadata["entitybank"]

        return True

    def process_characters(self, chars_list: typing.Any) -> bool:
        chars_path = self.assets_path / "chars"
        chars_ag_path = self.assetgen_path / "chars"

        char_entries: list[CharacterEntry] = [CharacterEntry(ce) for ce in chars_list]
        char_meta_paths: list[tuple[Path, str]] = []
        for char_entry in char_entries:
            char_prefix = char_entry.prefix

            ag_name = char_entry.name.lower().replace(" ", "_")
            ag_workdir = chars_ag_path / ag_name
            ag_workdir.mkdir(parents=True)

            # we are assuming the palette is the same across all images in this character
            made_palette_yet = False
            out_pal_path = ag_workdir / "palette.pal"

            self.add_header("Character " + char_entry.name)
            self.add_segment(char_entry.bank)

            for char_variant in char_entry.variants:
                variant_name = char_variant.name
                variant_name_lower = variant_name.lower()
                variant_full_name = char_prefix + "_" + variant_name
                variant_path = chars_path / char_variant.image
                variant_ag_path = ag_workdir / variant_name_lower

                if not run_stirchar2(
                    str(variant_path), str(variant_ag_path), variant_full_name
                ):
                    logging.error("stirchar returned an error, exiting now")
                    return False

                image_pairs = [
                    ("all_small", "AS"),
                    ("top_large", "TL"),
                    ("middle_large", "ML"),
                    ("bottom_large", "BL"),
                ]
                for image_pair in image_pairs:
                    image_name, label_suffix = image_pair
                    in_image_path = ag_workdir / (
                        variant_name_lower + "_" + image_name + ".png"
                    )
                    out_til_path = ag_workdir / (
                        variant_name_lower + "_" + image_name + ".til"
                    )
                    conv_args = {
                        "-i": str(in_image_path),
                        "-t": str(out_til_path),
                        "-R": "",
                        "-D": "",
                        "-F": "",
                        "-S": "",
                        "-B": "4",
                        "-W": "16",
                        "-H": "16",
                    }

                    if not made_palette_yet:
                        conv_args["-p"] = str(out_pal_path)

                    if not run_superfamiconv(self.tools_path, conv_args):
                        logging.error("superfamiconv returned an error, exiting now")
                        return False

                    if not made_palette_yet:
                        made_palette_yet = True
                        self.add_label(char_prefix + "_Palette_P")
                        self.add_include(out_pal_path, True)
                        self.add_label(char_prefix + "_Palette_PE")

                    tile_variant_prefix = (
                        char_prefix + "_" + variant_name + label_suffix
                    )
                    self.add_label(tile_variant_prefix + "_T")
                    self.add_include(out_til_path, True)
                    self.add_label(tile_variant_prefix + "_TE")

                out_meta_path = ag_workdir / (variant_name_lower + "_meta.asm")
                char_meta_paths.append((out_meta_path, variant_full_name))

        self.add_header("Character metasprite data")
        self.add_segment(self.char_table_bank)
        self.add_label("AChrAll_MetaTable")
        for char_meta_path in char_meta_paths:
            self.add_label(char_meta_path[1], True)
            self.add_include(char_meta_path[0], False)

        return True

    def process_backgrounds(self, bgs_list: typing.Any) -> bool:
        bgs_path = self.assets_path / "bgs"
        bgs_ag_path = self.assetgen_path / "bgs"

        bg_entries: list[BackgroundEntry] = [BackgroundEntry(be) for be in bgs_list]
        for bg_entry in bg_entries:
            ag_name = bg_entry.name.lower().replace(" ", "_")
            ag_workdir = bgs_ag_path / ag_name
            ag_workdir.mkdir(parents=True)

            bg_name = Path(bg_entry.image).stem
            bg_prefix = bg_entry.prefix

            in_image_path = bgs_path / bg_entry.image
            out_pal_path = ag_workdir / (bg_name + ".pal")
            out_til_path = ag_workdir / (bg_name + ".til")
            out_map_path = ag_workdir / (bg_name + ".map")
            conv_args = {
                "-i": str(in_image_path),
                "-p": str(out_pal_path),
                "-t": str(out_til_path),
                "-m": str(out_map_path),
                "-B": "4",
                "-W": "8",
                "-H": "8",
                "-Z": "000000",
            }

            if bg_entry.args:
                conv_args.update(bg_entry.args)

            if not run_superfamiconv(self.tools_path, conv_args):
                logging.error("superfamiconv returned an error, exiting now")
                return False

            if bg_entry.prio:
                set_high_prio(str(out_map_path))

            self.add_header("Background " + bg_entry.name)
            self.add_segment(bg_entry.bank)

            self.add_label(bg_prefix + "_Palette_P")
            self.add_include(out_pal_path, True)
            self.add_label(bg_prefix + "_Palette_PE")
            self.add_label(bg_prefix + "_Tileset_T")
            self.add_include(out_til_path, True)
            self.add_label(bg_prefix + "_Tileset_TE")
            self.add_label(bg_prefix + "_Tilemap_M")
            self.add_include(out_map_path, True)
            self.add_label(bg_prefix + "_Tilemap_ME")

        return True

    def process_tilesets(self, tsets_list: typing.Any) -> bool:
        worlds_path = self.assets_path / "worlds"
        worlds_ag_path = self.assetgen_path / "worlds"

        tset_entries: list[TilesetEntry] = [TilesetEntry(te) for te in tsets_list]
        for tset_entry in tset_entries:
            ag_name = tset_entry.name.lower().replace(" ", "_")
            ag_workdir = worlds_ag_path / ag_name
            ag_workdir.mkdir(parents=True)

            tset_name = Path(tset_entry.image).stem
            tset_prefix = tset_entry.prefix

            in_image_path = worlds_path / tset_entry.image
            in_pxa_path = worlds_path / tset_entry.attr
            out_pal_path = ag_workdir / (tset_name + ".pal")
            out_til_path = ag_workdir / (tset_name + ".til")
            out_wft_path = ag_workdir / (tset_name + ".wft")
            conv_args = {
                "-i": str(in_image_path),
                "-p": str(out_pal_path),
                "-t": str(out_til_path),
                "-B": "4",
                "-W": "8",
                "-H": "8",
                "-D": "",
                "-F": "",
                "-Z": "000000",
            }

            if tset_entry.args:
                conv_args.update(tset_entry.args)

            if not run_superfamiconv(self.tools_path, conv_args):
                logging.error("superfamiconv returned an error, exiting now")
                return False

            try:
                run_mapmetaconv(str(in_pxa_path), str(out_wft_path))
            except:
                logging.error("mapmetaconv returned an error, exiting now")
                return False

            self.add_header("Tileset " + tset_entry.name)
            self.add_segment(tset_entry.bank)

            self.add_label(tset_prefix + "_Palette_P")
            self.add_include(out_pal_path, True)
            self.add_label(tset_prefix + "_Palette_PE")
            self.add_label(tset_prefix + "_Tileset_T")
            self.add_include(out_til_path, True)
            self.add_label(tset_prefix + "_Tileset_TE")
            self.add_label(tset_prefix + "_Tilemeta_C")
            self.add_include(out_wft_path, True)
            self.add_label(tset_prefix + "_Tilemeta_CE")

        self.add_header("Tileset info data")
        self.add_segment(self.world_table_bank)
        self.add_label("AWorldTilesetAll_MetaTable")
        for tset_entry in tset_entries:
            tset_prefix = tset_entry.prefix
            self.lines.append(f"  {tset_prefix}_MetaTable:")
            # always assume palette is 0x20 bytes. if it's not, copying out of bounds is fine.
            self.lines.append(f"  .faraddr {tset_prefix}_Palette_P")
            self.lines.append(f"  .faraddr {tset_prefix}_Tileset_T")
            self.lines.append(f"  .faraddr {tset_prefix}_Tilemeta_C")
            self.lines.append(
                f"  .word ({tset_prefix}_Tileset_TE - {tset_prefix}_Tileset_T)"
            )
            self.lines.append(
                f"  .word ({tset_prefix}_Tilemeta_CE - {tset_prefix}_Tilemeta_C)"
            )
            self.lines.append("  .byte 0, 0, 0 ; padding")

        return True

    def process_worlds(self, worlds_list: typing.Any) -> bool:
        worlds_path = self.assets_path / "worlds"
        worlds_ag_path = self.assetgen_path / "worlds"

        world_entries: list[WorldEntry] = [WorldEntry(we) for we in worlds_list]
        for world_entry in world_entries:
            ag_name = world_entry.name.lower().replace(" ", "_")
            ag_workdir = worlds_ag_path / ag_name
            ag_workdir.mkdir(parents=True)

            world_path = worlds_path / world_entry.map
            world_prefix = world_entry.prefix

            out_wfm_root_path = ag_workdir / world_entry.map
            out_wfm_path = ag_workdir / (world_entry.map + ".wfm")
            out_wfe_path = ag_workdir / (world_entry.map + "_wfe.asm")
            out_asc_path = ag_workdir / (world_entry.map + "_asc.asm")

            self.add_header("World map " + world_entry.name)
            self.add_segment(world_entry.bank)

            try:
                run_mapconv(str(world_path), str(out_wfm_root_path))
            except:
                logging.error("mapconv returned an error, exiting now")
                return False

            self.add_label(world_prefix + "_LevelData_L")
            self.add_include(out_wfm_path, True)
            self.add_label(world_prefix + "_LevelData_LE")

            # n suffix was because entities used to be called "npcs"
            self.add_label(world_prefix + "_LevelEntities_N")
            self.add_include(out_wfe_path, False)
            self.add_label(world_prefix + "_LevelEntities_NE")

            self.add_label(world_prefix + "_LevelScripts_A")
            self.add_include(out_asc_path, False)
            self.add_label(world_prefix + "_LevelScripts_AE")

        self.add_header("Level info data")
        self.add_segment(self.world_table_bank)
        self.add_label("AWorldLevelAll_MetaTable")
        for world_entry in world_entries:
            world_prefix = world_entry.prefix
            self.lines.append(f"  {world_prefix}_MetaTable:")
            self.lines.append(f"  .faraddr {world_prefix}_LevelData_L")
            self.lines.append(f"  .faraddr {world_prefix}_LevelEntities_N")
            self.lines.append(
                f"  .byte ({world_entry.tileset}_MetaTable - AWorldTilesetAll_MetaTable) >> 4"
            )
            self.lines.append("  .byte 0 ; padding")

        return True

    def process_entities(self, entities_list: typing.Any) -> bool:
        entities_path = self.assets_path / "entities"
        entities_ag_path = self.assetgen_path / "entities"

        entity_entries: list[EntityEntry] = [EntityEntry(ee) for ee in entities_list]
        for entity_entry in entity_entries:
            ag_name = entity_entry.name.lower().replace(" ", "_")
            ag_workdir = entities_ag_path / ag_name
            ag_workdir.mkdir(parents=True)

            entity_name = Path(entity_entry.image).stem
            entity_prefix = entity_entry.prefix

            in_image_path = entities_path / entity_entry.image
            out_pal_path = ag_workdir / (entity_name + ".pal")
            out_til_path = ag_workdir / (entity_name + ".til")
            conv_args = {
                "-i": str(in_image_path),
                "-p": str(out_pal_path),
                "-t": str(out_til_path),
                "-R": "",
                "-D": "",
                "-F": "",
                "-S": "",
                "-B": "4",
                "-W": "16",
                "-H": "16",
            }

            if entity_entry.args:
                conv_args.update(entity_entry.args)

            if not run_superfamiconv(self.tools_path, conv_args):
                logging.error("superfamiconv returned an error, exiting now")
                return False

            self.add_header("Entity " + entity_entry.name)
            self.add_segment(entity_entry.bank)

            self.add_label(entity_prefix + "_Palette_P")
            self.add_include(out_pal_path, True)
            self.add_label(entity_prefix + "_Palette_PE")
            self.add_label(entity_prefix + "_Tileset_T")
            self.add_include(out_til_path, True)
            self.add_label(entity_prefix + "_Tileset_TE")

        self.add_header("Entity info data")
        self.add_segment(self.entity_table_bank)
        self.add_label("AEntityAll_MetaTable")
        for entity_entry in entity_entries:
            entity_prefix = entity_entry.prefix
            self.lines.append(f"  {entity_prefix}_MetaTable:")
            self.lines.append(f"  .faraddr {entity_prefix}_Palette_P")
            self.lines.append(f"  .faraddr {entity_prefix}_Tileset_T")
            self.lines.append(
                f"  .word ({entity_prefix}_Tileset_TE - {entity_prefix}_Tileset_T)"
            )

        return True

    def process_ui(self, ui_list: typing.Any) -> bool:
        ui_path = self.assets_path / "ui"
        ui_ag_path = self.assetgen_path / "ui"

        ui_entries: list[UiEntry] = [UiEntry(ue) for ue in ui_list]
        for ui_entry in ui_entries:
            ag_name = ui_entry.name.lower().replace(" ", "_")
            ag_workdir = ui_ag_path / ag_name

            if (
                ui_entry.type == "image"
                and ui_entry.image is not None
                and ui_entry.prio is not None
            ):
                ag_workdir.mkdir(parents=True)
                ui_name = Path(ui_entry.image).stem
                ui_prefix = ui_entry.prefix

                in_image_path = ui_path / ui_entry.image
                out_pal_path = ag_workdir / (ui_name + ".pal")
                out_til_path = ag_workdir / (ui_name + ".til")
                out_map_path = ag_workdir / (ui_name + ".map")
                conv_args = {
                    "-i": str(in_image_path),
                    "-p": str(out_pal_path),
                    "-t": str(out_til_path),
                    "-m": str(out_map_path),
                    "-B": "4",
                    "-W": "8",
                    "-H": "8",
                }

                if ui_entry.args:
                    conv_args.update(ui_entry.args)

                if not run_superfamiconv(self.tools_path, conv_args):
                    logging.error("superfamiconv returned an error, exiting now")
                    return False

                if ui_entry.prio:
                    set_high_prio(str(out_map_path))

                self.add_header("UI " + ui_entry.name)
                self.add_segment(ui_entry.bank)

                self.add_label(ui_prefix + "_Palette_P")
                self.add_include(out_pal_path, True)
                self.add_label(ui_prefix + "_Palette_PE")
                self.add_label(ui_prefix + "_Tileset_T")
                self.add_include(out_til_path, True)
                self.add_label(ui_prefix + "_Tileset_TE")
                self.add_label(ui_prefix + "_Tilemap_M")
                self.add_include(out_map_path, True)
                self.add_label(ui_prefix + "_Tilemap_ME")
            elif ui_entry.type == "palette" and ui_entry.data is not None:
                ui_prefix = ui_entry.prefix

                self.add_header("UI " + ui_entry.name)
                self.add_segment(ui_entry.bank)

                self.add_label(ui_prefix + "_Palette_P")
                for word in ui_entry.data:
                    self.lines.append("  .word $" + hex(word)[2:].zfill(4))

                self.add_label(ui_prefix + "_Palette_PE")

        return True

    def process_fonts(self, fonts_list: typing.Any) -> bool:
        fonts_path = self.assets_path / "fonts"
        fonts_ag_path = self.assetgen_path / "fonts"

        font_entries: list[FontEntry] = [FontEntry(fe) for fe in fonts_list]
        for font_entry in font_entries:
            ag_name = font_entry.name.lower().replace(" ", "_")
            ag_workdir = fonts_ag_path / ag_name
            ag_workdir.mkdir(parents=True)
            font_prefix = font_entry.prefix

            in_image_path = fonts_path / font_entry.image
            in_mapping_path = fonts_path / font_entry.mapping
            out_image_path = ag_workdir / "font.asm"

            res = run_makefonttable(
                str(in_image_path),
                str(in_mapping_path),
                font_prefix,
                str(out_image_path),
            )
            if not res:
                logging.error("makefonttable returned an error, exiting now")
                return False

            self.add_header("Font " + font_entry.name)
            self.add_segment(font_entry.bank)

            self.add_label(font_prefix + "_Widths", True)
            self.add_label(font_prefix + "_Strips", True)
            self.add_include(out_image_path, False)

        return True


def main(args: list[str]):
    # todo: take args
    assetman_path = Path(__file__).resolve().parent
    tools_path = assetman_path.parent
    project_path = tools_path.parent
    assets_path = project_path / "assets"
    assetgen_path = project_path / "assetgen"

    # wipe assetgen at startup since we'll be regenerating all of it
    if assetgen_path.exists():
        delete_folder_contents(assetgen_path)
    else:
        assetgen_path.mkdir()

    # run assets/index.py script and process config
    index_ns = run_path(str(assets_path / "index.py"))
    asset_index = index_ns["ASSET_INDEX"]

    logging.info("AssetMan starting up!")
    man = AssetManager(assets_path, assetgen_path, tools_path)

    while True:
        if "metadata" in asset_index:
            logging.info("Loading metadata...")
            if not man.process_metadata(asset_index["metadata"]):
                break
        if "chars" in asset_index:
            logging.info("Converting character data...")
            if not man.process_characters(asset_index["chars"]):
                break
        if "backgrounds" in asset_index:
            logging.info("Converting background data...")
            if not man.process_backgrounds(asset_index["backgrounds"]):
                break
        if "tilesets" in asset_index:
            logging.info("Converting tileset data...")
            if not man.process_tilesets(asset_index["tilesets"]):
                break
        if "worlds" in asset_index:
            logging.info("Converting platformer world data...")
            if not man.process_worlds(asset_index["worlds"]):
                break
        if "entities" in asset_index:
            logging.info("Converting platformer entity data...")
            if not man.process_entities(asset_index["entities"]):
                break
        if "ui" in asset_index:
            logging.info("Converting UI data...")
            if not man.process_ui(asset_index["ui"]):
                break
        if "fonts" in asset_index:
            logging.info("Converting font data...")
            if not man.process_fonts(asset_index["fonts"]):
                break

        break

    man.end_lines()
    man.write_lines()

    logging.info("AssetMan finished!")


if __name__ == "__main__":
    from colorlog import setup_logging

    setup_logging()

    main(sys.argv)
