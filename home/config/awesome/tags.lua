require("globals")

-- Tag configurations organized by screen role instead of numeric index
-- This makes tag assignment predictable regardless of screen detection order
return {
  -- Single screen configuration (fallback)
  single = {
    primary = {
      {
        name = TAGS[1],
        key = "r",
        layout = LAYOUT_MAX,
        master_width_factor = 0.5,
        master_fill_policy = "master_width_factor",
        master_count = 1,
        gap = 0,
      },
      {
        name = TAGS[2],
        key = "s",
        column_count = 1,
        gap_single_client = true,
        layout = LAYOUT_MAX,
        master_fill_policy = "master_width_factor",
        master_width_factor = 0.5,
      },
      {
        name = TAGS[3],
        key = "t",
        column_count = 1,
        gap_single_client = true,
        layout = LAYOUT_MAX,
        master_fill_policy = "master_width_factor",
        master_width_factor = 0.5,
        selected = true,
      },
      {
        name = TAGS[4],
        key = "x",
        layout = LAYOUT_MAX,
        master_width_factor = 0.5,
      },
      {
        name = TAGS[5],
        key = "c",
        layout = LAYOUT_MAX,
        master_width_factor = 0.5,
      },
      {
        name = TAGS[6],
        key = "d",
        layout = LAYOUT_MAX,
        master_width_factor = 0.5,
      },
      {
        name = TAGS[7],
        key = "w",
        layout = LAYOUT_MAX,
        master_width_factor = 0.5,
      },
      {
        name = TAGS[8],
        key = "f",
        layout = LAYOUT_MAX,
        master_width_factor = 0.7,
      },
      {
        name = TAGS[9],
        key = "p",
        layout = LAYOUT_MAX,
        master_width_factor = 0.5,
        gap = 0,
      },
      {
        name = TAGS[10],
        key = "a",
        layout = LAYOUT_MAX,
        master_width_factor = 0.66,
        gap = 0,
      },
      {
        name = TAGS[11],
        key = "b",
        layout = LAYOUT_MAX,
        master_width_factor = 0.5,
      },
      {
        name = TAGS[12],
        key = "g",
        layout = LAYOUT_MAX,
        master_width_factor = 0.5,
        selected = true,
      },
      {
        name = TAGS[13],
        key = "v",
        layout = LAYOUT_MAX,
        master_width_factor = 0.5,
      },
    }
  },
  -- Two screen configuration
  dual = {
    -- Split ultrawide (2 virtual screens from 1 physical ultrawide monitor)
    ultrawide_left = {
      {
        name = TAGS[6],
        key = "d",
        layout = LAYOUT_MAX,
        master_fill_policy = "expand",
        master_width_factor = 0.5,
      },
      {
        name = TAGS[11],
        key = "b",
        layout = LAYOUT_MAX,
        master_width_factor = 0.5,
      },
      {
        name = TAGS[10],
        key = "a",
        layout = LAYOUT_MAX,
        master_width_factor = 0.5,
        gap = 0,
        selected = true
      },
      {
        name = TAGS[7],
        key = "w",
        layout = LAYOUT_MAX,
        master_width_factor = 0.5,
      },
      {
        name = TAGS[2],
        key = "s",
        column_count = 1,
        gap_single_client = true,
        layout = LAYOUT_MAX,
        master_fill_policy = "expand",
        master_width_factor = 0.5,
        gap = 0
      },
      {
        name = TAGS[9],
        key = "p",
        layout = LAYOUT_MAX,
        master_width_factor = 0.5,
        gap = 0
      },
      {
        name = TAGS[12],
        key = "g",
        layout = LAYOUT_MAX,
        master_width_factor = 0.5,
        selected = true,
      }
    },
    ultrawide_right = {
      {
        name = TAGS[1],
        key = "r",
        layout = LAYOUT_MAX,
        master_width_factor = 0.5,
        master_fill_policy = "expand",
        master_count = 1,
        gap = 0,
      },
      {
        name = TAGS[8],
        key = "f",
        layout = LAYOUT_MAX,
        master_width_factor = 0.5,
      },
      {
        name = TAGS[3],
        key = "t",
        column_count = 1,
        gap_single_client = true,
        layout = LAYOUT_MAX,
        master_fill_policy = "expand",
        master_width_factor = 0.5,
        selected = true,
        gap = 0
      },
      {
        name = TAGS[4],
        key = "x",
        layout = LAYOUT_MAX,
        master_fill_policy = "expand",
        master_width_factor = 0.5,
      },
      {
        name = TAGS[5],
        key = "c",
        layout = LAYOUT_MAX,
        master_fill_policy = "expand",
        master_width_factor = 0.5,
      },
      {
        name = TAGS[13],
        key = "v",
        layout = LAYOUT_MAX,
        master_width_factor = 0.5,
      },
    },
    -- Standard dual monitors (builtin laptop + external, or 2 separate monitors)
    primary = {
      {
        name = TAGS[1],
        key = "r",
        layout = LAYOUT_MAX,
        master_width_factor = 0.5,
        master_fill_policy = "expand",
        master_count = 1,
        gap = 0,
      },
      {
        name = TAGS[8],
        key = "f",
        layout = LAYOUT_MAX,
        master_width_factor = 0.5,
      },
      {
        name = TAGS[3],
        key = "t",
        column_count = 1,
        gap_single_client = true,
        layout = LAYOUT_MAX,
        master_fill_policy = "expand",
        master_width_factor = 0.5,
        selected = true,
        gap = 0
      },
      {
        name = TAGS[4],
        key = "x",
        layout = LAYOUT_MAX,
        master_fill_policy = "expand",
        master_width_factor = 0.5,
      },
      {
        name = TAGS[5],
        key = "c",
        layout = LAYOUT_MAX,
        master_fill_policy = "expand",
        master_width_factor = 0.5,
      },
      {
        name = TAGS[9],
        key = "p",
        layout = LAYOUT_MAX,
        master_width_factor = 0.5,
        gap = 0
      },
      {
        name = TAGS[11],
        key = "b",
        layout = LAYOUT_MAX,
        master_width_factor = 0.5,
      },
      {
        name = TAGS[13],
        key = "v",
        layout = LAYOUT_MAX,
        master_width_factor = 0.5,
      },
    },
    secondary = {
      {
        name = TAGS[6],
        key = "d",
        layout = LAYOUT_MAX,
        master_fill_policy = "expand",
        master_width_factor = 0.5,
      },
      {
        name = TAGS[10],
        key = "a",
        layout = LAYOUT_MAX,
        master_width_factor = 0.5,
        gap = 0,
        selected = true
      },
      {
        name = TAGS[7],
        key = "w",
        layout = LAYOUT_MAX,
        master_width_factor = 0.5,
      },
      {
        name = TAGS[2],
        key = "s",
        column_count = 1,
        gap_single_client = true,
        layout = LAYOUT_MAX,
        master_fill_policy = "expand",
        master_width_factor = 0.5,
        gap = 0
      },
      {
        name = TAGS[12],
        key = "g",
        layout = LAYOUT_MAX,
        master_width_factor = 0.5,
        selected = true,
      }
    }
  },
  -- Three screen configuration (split ultrawide + external monitor)
  triple = {
    ultrawide_left = {
      {
        name = TAGS[6],
        key = "d",
        layout = LAYOUT_MAX,
        master_fill_policy = "master_width_factor",
        master_width_factor = 0.5,
        selected = true,
      },
      {
        name = TAGS[11],
        key = "b",
        layout = LAYOUT_MAX,
        master_width_factor = 0.5,
      },
      {
        name = TAGS[10],
        key = "a",
        layout = LAYOUT_MAX,
        master_width_factor = 0.5,
        gap = 0,
      },
      {
        name = TAGS[7],
        key = "w",
        layout = LAYOUT_MAX,
        master_width_factor = 0.5,
      },
      {
        name = TAGS[2],
        key = "s",
        column_count = 1,
        gap_single_client = true,
        layout = LAYOUT_MAX,
        master_fill_policy = "master_width_factor",
        master_width_factor = 0.5,
        gap = 0
      },
      {
        name = TAGS[9],
        key = "p",
        layout = LAYOUT_MAX,
        master_width_factor = 0.5,
        gap = 0
      }
    },
    ultrawide_right = {
      {
        name = TAGS[1],
        key = "r",
        layout = LAYOUT_MAX,
        master_width_factor = 0.5,
        master_fill_policy = "master_width_factor",
        master_count = 1,
        gap = 0,
        selected = true,
      },
      {
        name = TAGS[8],
        key = "f",
        layout = LAYOUT_MAX,
        master_width_factor = 0.5,
      },
      {
        name = TAGS[3],
        key = "t",
        column_count = 1,
        gap_single_client = true,
        layout = LAYOUT_MAX,
        master_fill_policy = "master_width_factor",
        master_width_factor = 0.5,
        gap = 0
      },
      {
        name = TAGS[4],
        key = "x",
        layout = LAYOUT_MAX,
        master_fill_policy = "master_width_factor",
        master_width_factor = 0.5,
      },
      {
        name = TAGS[5],
        key = "c",
        layout = LAYOUT_MAX,
        master_fill_policy = "master_width_factor",
        master_width_factor = 0.5,
      },
      {
        name = TAGS[13],
        key = "v",
        layout = LAYOUT_MAX,
        master_width_factor = 0.5,
      },
    },
    external = {
      {
        name = TAGS[12],
        key = "g",
        layout = LAYOUT_MAX,
        master_width_factor = 0.5,
        selected = true,
      },
    },
  }
}
