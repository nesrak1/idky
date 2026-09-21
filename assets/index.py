ASSET_INDEX = {
    # bank locations
    "metadata": {"charbank": "MODEVN_CODE", "worldbank": "MODEPF_CODE"},
    # VN character sprites
    "chars": [
        {
            "name": "Lucy",
            "prefix": "AChrLucy",
            "bank": "MODEVN_AS_CHR1",
            "charid": 0,
            "variants": [{"name": "Smile", "image": "lucy_smile.png"}],
        }
    ],
    # VN background images
    "backgrounds": [
        {
            "name": "Classroom",
            "prefix": "ABkgClassroom1",
            "bank": "MODEVN_AS_BG1",
            "bgid": 0,
            "image": "classroom-sketchfab3_p.png",
            "prio": False,
        }
    ],
    # platformer tilesets
    "tilesets": [
        {
            "name": "SpiritWorld",
            "prefix": "ASpiritVoidTileset",
            "bank": "MODEPF_AS_LV1",
            "tsid": 0,
            "image": "Ch0.png",
            "attr": "Ch0.pxa",
        }
    ],
    # platformer levels
    "worlds": [
        {
            "name": "SpiritWorld0",
            "prefix": "ASpiritVoidLevel0",
            "bank": "MODEPF_AS_LV1",
            "lvid": 0,
            "map": "Ch0Lv0",
            "tileset": "ASpiritVoidTileset",
        }
    ],
    # various UI elements
    "ui": [
        {
            "name": "ChatboxDark",
            "type": "image",
            "prefix": "AUiChatboxDark",
            "bank": "MODEVN_AS_UI",
            "image": "chatbox-dark.png",
            "prio": True,
            "args": {"--palette-base-offset": "1", "--tile-base-offset": "1"},
        },
        {
            "name": "ChatboxDarkPalette",
            "type": "palette",
            "prefix": "AUiChatboxText",
            "bank": "MODEVN_AS_UI",
            "data": [0x0000, 0xFFFF, 0x0000, 0xFFFF],
        },
    ],
    # UI fonts
    "fonts": [
        {
            "name": "Terv12b",
            "prefix": "AText",
            "bank": "MODEVN_CODE",
            "image": "terv12b.png",
            "mapping": "terv12b.txt",
        }
    ],
}
