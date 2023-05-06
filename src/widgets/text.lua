--- A collection of Widget classes
-- @module widget_text
-- @alias wt

pcall(function() require('cairo') end)

local data = require('src/data')
local util = require('src/util')
local ch = require('src/cairo_helpers')
local core = require('src/widgets/core')
local Widget = core.Widget

-- lua 5.1 to 5.3 compatibility
local unpack = unpack or table.unpack  -- luacheck: read_globals unpack table
local floor, ceil, clamp = math.floor, math.ceil, util.clamp


--- Common (abstract) base class for `StaticText` and `TextLine`.
-- @type Text
local Text = util.class(Widget)
w.Text = Text

local write_aligned = {left = ch.write_left,
                       center = ch.write_centered,
                       right = ch.write_right}

--- @tparam table args table of options
-- @tparam ?string args.align "left" (default), "center" or "right"
-- @tparam[opt=current_theme.default_font_family] ?string args.font_family
-- @tparam[opt=current_theme.default_font_size] ?number args.font_size
-- @tparam[opt=CAIRO_FONT_SLANT_NORMAL] ?cairo_font_slant_t args.font_slant
-- @tparam[opt=CAIRO_FONT_WEIGHT_NORMAL] ?cairo_font_weight_t args.font_weight
-- @tparam ?{number,number,number,number} args.color (default: `default_text_color`)
function Text:init(args)
    assert(getmetatable(self) ~= Text, "Cannot instanciate class Text directly.")
    self._align = args.align or "left"
    self._font_family = args.font_family or current_theme.default_font_family
    self._font_size = args.font_size or current_theme.default_font_size
    self._font_slant = args.font_slant or CAIRO_FONT_SLANT_NORMAL
    self._font_weight = args.font_weight or CAIRO_FONT_WEIGHT_NORMAL
    self._color = args.color or current_theme.default_text_color

    self._write_fn = write_aligned[self._align]

    -- try to match conky's line spacing:
    local font_extents = ch.font_extents(self._font_family, self._font_size,
                                         self._font_slant, self._font_weight)
    self._line_height = font_extents.height + 1

    local line_spacing = font_extents.height - (font_extents.ascent + font_extents.descent)
    self._baseline_offset = font_extents.ascent + 0.5 * line_spacing + 1
end

function Text:layout(width)
    if self._align == "center" then
        self._x = 0.5 * width
    elseif self._align == "left" then
        self._x = 0
    else  -- self._align == "right"
        self._x = width
    end
end


--- Draw some unchangeable text.
-- Use this widget for text that will never be updated.Text
-- @type StaticText
local StaticText = util.class(Text)
w.StaticText = StaticText

--- @string text Text to be displayed.
-- @tparam ?table args table of options, see `Text:init`
function StaticText:init(text, args)
    Text.init(self, args or {})

    self._lines = {}
    text = text .. "\n"

    for line in text:gmatch("(.-)\n") do
        table.insert(self._lines, line)
    end

    self.height = #self._lines * self._line_height
end

function StaticText:render_background(cr)
    ch.set_font(cr, self._font_family, self._font_size, self._font_slant,
                    self._font_weight)
    cairo_set_source_rgba(cr, unpack(self._color))
    for i, line in ipairs(self._lines) do
        local y = self._baseline_offset + (i - 1) * self._line_height
        self._write_fn(cr, self._x, y, line)
    end
end


--- Draw a single line of changeable text.
-- Text line can be updated on each cycle via `set_text`.
-- @type TextLine
local TextLine = util.class(Text)
w.TextLine = TextLine

--- @tparam table args table of options, see `Text:init`
function TextLine:init(args)
    Text.init(self, args)
    self.height = self._line_height
end

--- Update the text line to be displayed.
-- @string text
function TextLine:set_text(text)
    self._text = text
end

function TextLine:render(cr)
    ch.set_font(cr, self._font_family, self._font_size, self._font_slant,
                    self._font_weight)
    cairo_set_source_rgba(cr, unpack(self._color))
    self._write_fn(cr, self._x, self._baseline_offset, self._text)
end


return w
