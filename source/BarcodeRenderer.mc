// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Daniele Gagliardi
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version. See LICENSE for details.
// Additional terms (GPL-3.0 sections 7(b) and 7(c)): see NOTICE.

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// Barcode renderer: QR (spec-compliant encoder, versions 1-4, ECC L) and
// Code 39 (A-Z 0-9 and basic symbols, sufficient for all national IDs).
// Code128 and PDF417 were dropped; see drawBarcodeAt() for why.
class BarcodeRenderer {
    private const CODE39_CHARS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-. *$/+%";

    // Standard Code 39 table: 9 elements per character (5 bars + 4 spaces,
    // bar first, alternating). '1' = wide (3 units), '0' = narrow (1 unit).
    private const CODE39_PATTERNS = [
        "000110100",  // 0
        "100100001",  // 1
        "001100001",  // 2
        "101100000",  // 3
        "000110001",  // 4
        "100110000",  // 5
        "001110000",  // 6
        "000100101",  // 7
        "100100100",  // 8
        "001100100",  // 9
        "100001001",  // A
        "001001001",  // B
        "101001000",  // C
        "000011001",  // D
        "100011000",  // E
        "001011000",  // F
        "000001101",  // G
        "100001100",  // H
        "001001100",  // I
        "000011100",  // J
        "100000011",  // K
        "001000011",  // L
        "101000010",  // M
        "000010011",  // N
        "100010010",  // O
        "001010010",  // P
        "000000111",  // Q
        "100000110",  // R
        "001000110",  // S
        "000010110",  // T
        "110000001",  // U
        "011000001",  // V
        "111000000",  // W
        "010010001",  // X
        "110010000",  // Y
        "011010000",  // Z
        "010000101",  // -
        "110000100",  // .
        "011000100",  // space
        "010010100",  // *
        "010101000",  // $
        "010100010",  // /
        "010001010",  // +
        "000101010"   // %
    ];

    // Must stay an integer: element widths are accumulated into the bar X
    // position, and a fractional ratio (2.5 was tried) makes each "wide"
    // element land on a .5 boundary that fillRectangle truncates
    // inconsistently: the same wide bar renders 2px here and 3px there,
    // destroying the wide:narrow ratio a Code 39 scanner decodes on.
    // CHAR_UNITS below is derived from this value and must match it.
    private const WIDE_RATIO  = 3;   // wide element = 3 narrow units (spec: 2..3)
    private const QUIET_UNITS = 10;  // quiet zone on each side, in narrow units
    // Each char: 6 narrow + 3 wide = 6 + (3 * WIDE_RATIO) = 15 units,
    // + 1 inter-char gap = 16
    private const CHAR_UNITS  = 16;

    // A narrow bar this many pixels wide or less cannot be resolved by a real
    // scanner (laser/camera minimum X-dimension is ~0.19mm; on a 1.3" watch
    // face 1px is roughly 0.06mm). Below this we show the value as readable
    // text instead of a barcode nobody can actually scan.
    private const MIN_SCANNABLE_UNIT = 2;

    // Hint shown under the value on a fallback panel, explaining why bars/
    // modules were replaced by text. Swapping them silently reads as a broken
    // app rather than a deliberate decision.
    private const HINT_NONE        = 0;  // nothing useful to suggest
    private const HINT_USE_QR      = 1;  // Code 39 cannot fit this value
    private const HINT_QR_TOO_LONG = 2;  // value exceeds QR version 4 capacity
    private const HINT_UNSUPPORTED = 3;  // value has characters Code 39 lacks
    private const HINT_QR_NO_MEMORY = 4; // too little free memory to build a QR

    // Horizontal inset on round displays so bars and white panel stay inside
    // the circular mask. On rectangular displays this is just padding.
    // Do not shrink this to gain barcode width: on a round display the panel
    // would be clipped by the bezel mask, and the extra pixels are far too
    // few to change whether a barcode fits (see MIN_SCANNABLE_UNIT).
    private const SIDE_MARGIN = 16;

    // QR matrix generation (RS error correction, module placement)
    // is expensive and was being redone from scratch on every single
    // onUpdate() (every scroll keypress, every redraw) with no caching.
    // For a larger QR (e.g. a 58-char payload needing version 3, vs. a
    // truncated 32-char one needing version 2) this could run long enough
    // to blow the render/watchdog budget on a MIP device (reported as the
    // app "freezing"). Cache the built matrix per (docType, text) and only
    // rebuild when the content actually changes.
    private var cachedKey     as String?;
    private var cachedModules as ByteArray?;

    // QR build in progress. Building runs on a timer, one stage per tick
    // (see buildStep), never inside onUpdate(): done in one go it tripped
    // the watchdog ("Code Executed Too Long") on slower watches such as the
    // Forerunner 55, whose onUpdate() also does all the text layout.
    private var buildKey      as String?;
    private var buildText     as String = "";
    private var buildStage    as Number = 0;
    private var buildVersion  as Number = 0;
    private var buildN        as Number = 0;
    private var buildWords    as ByteArray?;   // data, then data + EC codewords
    private var buildModules  as ByteArray?;
    private var buildIsFn     as ByteArray?;
    private var buildCol      as Number = 0;   // placement: next column pair
    private var buildBitIndex as Number = 0;   // placement: next codeword bit
    private var buildRow      as Number = 0;   // masking: next row
    private var buildTimer    as Timer.Timer?;

    // Whether the last drawBarcodeAt() call actually had the panel on screen.
    // The view uses this to decide about the backlight, instead of trying to
    // re-derive the panel height itself (its estimate did not match what QR
    // actually produces, so the backlight could trigger early or late).
    private var lastBarcodeVisible as Boolean = false;

    function initialize() {}

    function isLastBarcodeVisible() as Boolean { return lastBarcodeVisible; }

    //! True when a panel of panelH starting at topY intersects the viewport.
    //! Everything below is drawn inside a scrolling column, so most of the
    //! time the barcode sits far outside the screen; skipping the draw there
    //! avoids up to ~1100 fillRectangle() calls per frame for a version-4 QR
    //! (the matrix is cached, but the drawing loop was not being skipped).
    private function checkVisible(topY as Number, panelH as Number,
                                   screenH as Number) as Boolean {
        var visible = (topY < screenH) && ((topY + panelH) > 0);
        if (visible) { lastBarcodeVisible = true; }
        return visible;
    }

    //! Dispatch barcode rendering based on format type.
    //! 0 = None, 1 = QR, 2 = Code 39 (generic)
    //! Code128 and PDF417 were dropped: real-world usefulness for a
    //! responder without a proper scanner is low (see CHANGELOG), and
    //! neither followed the actual standard needed to interoperate with
    //! real hospital/DMV scanning systems anyway. QR (any phone camera) and
    //! Code39 (simple, reliable) cover the practical cases.
    //! Always returns the bottom Y of the section (including bottom padding)
    //! whether or not it was actually drawn, so scroll extents stay correct.
    //! reservedAbove: height of what the view draws right above the panel
    //! (the code label), which must fit on screen together with it.
    function drawBarcodeAt(dc as Dc, docType as Number, text as String,
                            topY as Number, screenH as Number,
                            reservedAbove as Number) as Number {
        lastBarcodeVisible = false;
        // Below a subscreen, the panel and its label share what is left of
        // the screen height; see subscreenBottom().
        var sub = subscreenBottom();
        maxPanelH = sub > 0 ? screenH - sub - reservedAbove - 6 : screenH;
        switch (docType) {
            case 1: return drawQrAt(dc, text, topY, screenH);
            case 2: return drawCode39At(dc, text, topY, screenH);
            default: return topY;
        }
    }

    // Tallest panel that fits on screen with its label (set per call by
    // drawBarcodeAt).
    private var maxPanelH as Number = 0;

    //! Bottom edge of the subscreen (the small separate round display in
    //! the top-right corner of the Instinct 2/2S/2X/Crossover/3 Solar/E and
    //! Descent G1), or 0 on watches without one. Content drawn in its
    //! bounding box is partly hidden by the subscreen's frame and corners on
    //! the real watch, which in the simulator is easy to miss: a QR centred
    //! on an Instinct 2 had its top-right finder pattern under it, and a code
    //! missing a finder pattern often does not scan. The view stops the
    //! barcode block just below this edge, and the panel is sized to fit.
    function subscreenBottom() as Number {
        if (WatchUi has :getSubscreen) {
            var box = WatchUi.getSubscreen();
            if (box != null) {
                return (box as Graphics.BoundingBox).y + (box as Graphics.BoundingBox).height;
            }
        }
        return 0;
    }

    //! Calculate safe square size for QR on round displays.
    //! Returns dimension that fits inside circular mask without clipping.
    private function safeSquareSize(dc as Dc) as Number {
        var settings = System.getDeviceSettings();
        var shape = settings.screenShape;
        var w = dc.getWidth();
        var h = dc.getHeight();
        var base = w < h ? w : h;
        var size = (shape == System.SCREEN_SHAPE_ROUND)
            ? (base * 0.70).toNumber() : (base * 0.85).toNumber();
        return size < maxPanelH ? size : maxPanelH;
    }

    //! QR code renderer (medical insurance / digital health).
    //! Full spec-compliant QR encoder: alphanumeric/byte mode, versions 1-4,
    //! ECC level L, Reed-Solomon (GF(256)) error correction, mask 0, real
    //! finder/timing/alignment/format-info placement. Scannable output.
    //! Devices below API 3.0.0 (Forerunner 230/235/630/735XT/920XT, fenix 3,
    //! D2 Bravo and some D2 Charlie part numbers, vivoactive and vivoactive
    //! HR, epix, Approach S60) have no
    //! ByteArray, which the encoder needs to fit in a widget's memory, and
    //! referencing it there is a compile error rather than something to
    //! check at runtime. monkey.jungle builds them with this variant, which
    //! says so instead of drawing a QR. None of them could draw one before
    //! either: the old memory gate was out of their reach.
    (:noQrEncoder)
    private function drawQrAt(dc as Dc, text as String, topY as Number,
                               screenH as Number) as Number {
        return drawTextFallbackAt(dc, text, topY, screenH, HINT_QR_NO_MEMORY);
    }

    (:qrEncoder)
    private function drawQrAt(dc as Dc, text as String, topY as Number,
                               screenH as Number) as Number {
        // Fallback panels show the plain value: the "[QR] " prefix that used
        // to be prepended here was internal notation leaking into an
        // emergency screen, where every character on display should be
        // information a responder can act on.
        var key = "qr:" + text;
        if (cachedKey != null && (cachedKey as String).equals(key)) {
            if (cachedModules == null) {
                return drawTextFallbackAt(dc, text, topY, screenH, HINT_QR_TOO_LONG);
            }
            var modules = cachedModules as ByteArray;
            return renderModuleMatrix(dc, modules, Math.sqrt(modules.size()).toNumber(),
                                      topY, screenH);
        }
        var versionIdx = qrVersionFor(text);
        if (versionIdx < 0) {
            cachedKey = key;
            cachedModules = null;
            return drawTextFallbackAt(dc, text, topY, screenH, HINT_QR_TOO_LONG);
        }
        if (buildKey == null || !(buildKey as String).equals(key)) {
            // The memory check only guards building: a cached matrix costs
            // nothing more to draw.
            if (!hasMemoryToBuildQr()) {
                return drawTextFallbackAt(dc, text, topY, screenH, HINT_QR_NO_MEMORY);
            }
            startQrBuild(text, key, versionIdx);
        }
        // Still building: an empty panel of the final size, so the layout,
        // the scroll stops and the backlight decision are already right.
        return renderModuleMatrix(dc, null, QR_SIZES[versionIdx], topY, screenH);
    }

    //! Free heap required before building a QR. The encoder keeps everything
    //! in ByteArrays (one byte per module or codeword): its peak is the two
    //! 33x33 grids, 1089 bytes each, plus under 1 KB of codewords and GF(256)
    //! tables, and a UTF-8 copy of the payload. This leaves a wide margin
    //! over that.
    //! It replaces a fixed `totalMemory >= 100000` gate, sized for an older
    //! encoder that stored every module and every bit as a separate Array
    //! element. That gate refused QR outright on every watch whose widgets
    //! get 64 KB (Forerunner 55, Instinct 2/2X/2S, Forerunner 245 and
    //! more), about a quarter of the installed base, which saw plain text
    //! with no explanation instead.
    private const QR_MIN_FREE_MEMORY = 8192;

    (:qrEncoder)
    private function hasMemoryToBuildQr() as Boolean {
        return System.getSystemStats().freeMemory >= QR_MIN_FREE_MEMORY;
    }

    //! Modules of quiet zone (blank border) on each side. The QR spec
    //! requires a minimum 4-module quiet zone for reliable finder-pattern
    //! detection by scanners: a fixed pixel margin (regardless of module
    //! size) was previously used instead, which was both too small for
    //! larger modules (scan failures) and added ON TOP of the pre-computed
    //! "safe" circular-display footprint (visual overflow past the safe
    //! area on round screens).
    private const QUIET_ZONE_MODULES = 4;

    //! Renders an n x n module grid (QR, row-major, nonzero = dark) as a
    //! white panel with black modules. With modules null (QR still being
    //! built) it draws the empty panel only.
    (:qrEncoder)
    private function renderModuleMatrix(dc as Dc, modules as ByteArray?, n as Number,
                                         topY as Number, screenH as Number) as Number {
        var fullWidth  = dc.getWidth();
        var widthBudget = safeSquareSize(dc);
        // Reserve the quiet zone's module-equivalent width WITHIN the safe
        // footprint budget, instead of adding it on top afterward.
        var moduleSize = widthBudget / (n + (QUIET_ZONE_MODULES * 2));
        if (moduleSize < 1) { moduleSize = 1; }

        var quiet  = QUIET_ZONE_MODULES * moduleSize;
        var panelW = (n * moduleSize) + (2 * quiet);
        var panelH = panelW;
        var panelX = (fullWidth - panelW) / 2;

        if (!checkVisible(topY, panelH, screenH)) {
            return topY + panelH + 60;
        }

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(panelX, topY, panelW, panelH);

        if (modules == null) {
            return topY + panelH + 60;
        }
        var grid = modules as ByteArray;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        for (var r = 0; r < n; r++) {
            for (var c = 0; c < n; c++) {
                if (grid[(r * n) + c] != 0) {
                    dc.fillRectangle(panelX + quiet + (c * moduleSize),
                                      topY + quiet + (r * moduleSize),
                                      moduleSize, moduleSize);
                }
            }
        }
        return topY + panelH + 60;
    }

    // ---------------------------------------------------------------
    // QR encoder (versions 1-4, ECC level L)
    //
    // All working storage is ByteArray, one byte per value: grids are flat
    // and row-major (cell (r, c) is at r * n + c). Plain Arrays of Boolean or
    // Number cost several bytes per element plus a header per row, which put
    // the encoder out of reach of 64 KB widgets.
    // ---------------------------------------------------------------

    private const QR_ALPHANUMERIC = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:";

    //! Writes the low `length` bits of value, most significant first, at bit
    //! position pos of buf (which must start zeroed). Returns the new pos.
    (:qrEncoder)
    private function writeBits(buf as ByteArray, pos as Number, value as Number,
                               length as Number) as Number {
        for (var i = length - 1; i >= 0; i--) {
            if (((value >> i) & 1) == 1) {
                buf[pos / 8] = buf[pos / 8] | (0x80 >> (pos % 8));
            }
            pos++;
        }
        return pos;
    }

    (:qrEncoder)
    private function isAlphanumericQr(text as String) as Boolean {
        for (var i = 0; i < text.length(); i++) {
            if (QR_ALPHANUMERIC.find(text.substring(i, i + 1)) == null) {
                return false;
            }
        }
        return true;
    }

    //! exp has 512 entries so exp[a + b] needs no modulo for a, b < 255.
    (:qrEncoder)
    private function buildGfExp() as ByteArray {
        var expTable = new [512]b;
        var val = 1;
        for (var i = 0; i < 255; i++) {
            expTable[i] = val;
            val = val * 2;
            if (val >= 256) { val = val ^ 0x11D; }
        }
        for (var i = 255; i < 512; i++) { expTable[i] = expTable[i - 255]; }
        return expTable;
    }

    (:qrEncoder)
    private function buildGfLog(expTable as ByteArray) as ByteArray {
        var logTable = new [256]b;
        for (var i = 0; i < 255; i++) { logTable[expTable[i]] = i; }
        return logTable;
    }

    (:qrEncoder)
    private function rsGeneratorPoly(ecCount as Number, exp as ByteArray,
                                     log as ByteArray) as ByteArray {
        var poly = new [1]b;
        poly[0] = 1;
        for (var i = 0; i < ecCount; i++) {
            var newPoly = new [poly.size() + 1]b;
            for (var j = 0; j < poly.size(); j++) {
                newPoly[j] = newPoly[j] ^ poly[j];
                var product = (poly[j] == 0) ? 0 : exp[(log[poly[j]] + i) % 255];
                newPoly[j + 1] = newPoly[j + 1] ^ product;
            }
            poly = newPoly;
        }
        return poly;
    }

    (:qrEncoder)
    private function rsComputeRemainder(data as ByteArray, ecCount as Number,
                                        exp as ByteArray, log as ByteArray) as ByteArray {
        var generator = rsGeneratorPoly(ecCount, exp, log);
        var remainder = new [ecCount]b;
        for (var i = 0; i < data.size(); i++) {
            var factor = data[i] ^ remainder[0];
            for (var j = 0; j < ecCount - 1; j++) { remainder[j] = remainder[j + 1]; }
            remainder[ecCount - 1] = 0;
            if (factor != 0) {
                var logFactor = log[factor];
                for (var j = 0; j < ecCount; j++) {
                    if (generator[j + 1] != 0) {
                        remainder[j] = remainder[j] ^ exp[(log[generator[j + 1]] + logFactor) % 255];
                    }
                }
            }
        }
        return remainder;
    }

    //! Reserves the finder pattern (7x7) plus its 1-module white separator
    //! on ALL sides facing the data area. BUG FIX: rowEnd/colEnd previously
    //! used `+7` (only covering the 7x7 finder itself), while rowStart/
    //! colStart used `-1` (correctly extending into the separator on the
    //! outward side). This meant the separator strip on the INWARD-facing
    //! side (e.g. the row below a top-aligned finder, or the column right
    //! of a left-aligned finder) was never reserved: data got placed and
    //! masked there instead of being kept a clean white separator, which is
    //! exactly what a real ISO/IEC 18004 decoder expects at fixed positions
    //! to detect and align each finder pattern. This silently produced a
    //! structurally QR-looking image with correct-looking finder squares
    //! (confirmed by OpenCV/zbar finding them) that nonetheless failed to
    //! decode, verified via an independent Python re-implementation cross-
    //! checked against the `qrcode` reference library's module matrix and
    //! zbar decoding.
    (:qrEncoder)
    private function markFinderArea(modules as ByteArray, isFn as ByteArray, n as Number,
                                     top as Number, left as Number) as Void {
        var rowStart = top - 1; if (rowStart < 0) { rowStart = 0; }
        var rowEnd   = top + 8; if (rowEnd > n) { rowEnd = n; }
        var colStart = left - 1; if (colStart < 0) { colStart = 0; }
        var colEnd   = left + 8; if (colEnd > n) { colEnd = n; }
        for (var r = rowStart; r < rowEnd; r++) {
            for (var c = colStart; c < colEnd; c++) {
                isFn[(r * n) + c] = 1;
                modules[(r * n) + c] = 0;
            }
        }
        for (var dr = 0; dr < 7; dr++) {
            for (var dc = 0; dc < 7; dc++) {
                var black = (dr == 0 || dr == 6 || dc == 0 || dc == 6 ||
                             (dr >= 2 && dr <= 4 && dc >= 2 && dc <= 4));
                modules[((top + dr) * n) + left + dc] = black ? 1 : 0;
            }
        }
    }

    (:qrEncoder)
    private function drawTimingPatterns(modules as ByteArray, isFn as ByteArray, n as Number) as Void {
        for (var i = 8; i < n - 8; i++) {
            var black = ((i % 2) == 0) ? 1 : 0;
            modules[(6 * n) + i] = black; isFn[(6 * n) + i] = 1;
            modules[(i * n) + 6] = black; isFn[(i * n) + 6] = 1;
        }
    }

    //! BUG FIX: must reserve exactly the cells setFormatBits() writes to
    //! (see that function for the corrected placement). The previous
    //! version under-reserved one column (row 8, col n-8), letting
    //! placeQrData() consume a real data bit into a cell that setFormatBits
    //! unconditionally overwrites afterward, silently dropping one bit and
    //! shifting every subsequent bit in the zig-zag traversal by one
    //! position, corrupting the entire rest of the payload.
    (:qrEncoder)
    private function reserveFormatAreas(isFn as ByteArray, n as Number) as Void {
        // Column 8 (vertical copy): rows 0-5, 7, 8, then n-7..n-1, plus the
        // fixed dark module at row n-8.
        for (var i = 0; i <= 5; i++) { isFn[(i * n) + 8] = 1; }
        isFn[(7 * n) + 8] = 1;
        isFn[(8 * n) + 8] = 1;
        for (var i = n - 7; i <= n - 1; i++) { isFn[(i * n) + 8] = 1; }
        isFn[((n - 8) * n) + 8] = 1;

        // Row 8 (horizontal copy): cols 0-5, 7, then n-8..n-1.
        for (var i = 0; i <= 5; i++) { isFn[(8 * n) + i] = 1; }
        isFn[(8 * n) + 7] = 1;
        for (var i = n - 8; i <= n - 1; i++) { isFn[(8 * n) + i] = 1; }
    }

    (:qrEncoder)
    private function drawAlignmentPattern(modules as ByteArray, isFn as ByteArray, n as Number,
                                          center as Number) as Void {
        for (var dr = -2; dr <= 2; dr++) {
            for (var dc = -2; dc <= 2; dc++) {
                var idx = ((center + dr) * n) + center + dc;
                var black = (dr == -2 || dr == 2 || dc == -2 || dc == 2 || (dr == 0 && dc == 0));
                modules[idx] = black ? 1 : 0;
                isFn[idx] = 1;
            }
        }
    }

    //! Zig-zag data placement (Nayuki-style: two-column strips, skipping the
    //! vertical timing column, alternating scan direction each strip).
    //! Resumable: places at most maxStrips strips per call, carrying the
    //! position in buildCol / buildBitIndex. Returns true when done.
    (:qrEncoder)
    private function placeQrData(modules as ByteArray, isFn as ByteArray, n as Number,
                                 codewords as ByteArray, maxStrips as Number) as Boolean {
        var bitLen = codewords.size() * 8;
        var bitIndex = buildBitIndex;
        var col = buildCol;
        var strips = 0;
        while (col >= 1 && strips < maxStrips) {
            if (col == 6) { col = 5; }
            for (var vert = 0; vert < n; vert++) {
                for (var j = 0; j < 2; j++) {
                    var c = col - j;
                    var upward = (((col + 1) & 2) == 0);
                    var row = upward ? (n - 1 - vert) : vert;
                    if (isFn[(row * n) + c] == 0) {
                        var bit = 0;
                        if (bitIndex < bitLen) {
                            bit = (codewords[bitIndex / 8] >> (7 - (bitIndex % 8))) & 1;
                            bitIndex++;
                        }
                        modules[(row * n) + c] = bit;
                    }
                }
            }
            col -= 2;
            strips++;
        }
        buildCol = col;
        buildBitIndex = bitIndex;
        return col < 1;
    }

    //! Mask pattern 0 over rows fromRow (inclusive) to toRow (exclusive).
    (:qrEncoder)
    private function applyMask0(modules as ByteArray, isFn as ByteArray, n as Number,
                                fromRow as Number, toRow as Number) as Void {
        for (var r = fromRow; r < toRow; r++) {
            for (var c = 0; c < n; c++) {
                var idx = (r * n) + c;
                if (isFn[idx] == 0 && (((r + c) % 2) == 0)) {
                    modules[idx] = 1 - modules[idx];
                }
            }
        }
    }

    //! BCH(15,5) format info for ECC level L + mask 0, XORed with the fixed
    //! format mask 0x5412 per the QR spec.
    (:qrEncoder)
    private function computeFormatBits() as Number {
        var data = 0x08; // ECC L = 01, mask = 000
        var reg = data << 10;
        var poly = 0x537; // degree-10 generator, 11 bits
        for (var i = 14; i >= 10; i--) {
            if (((reg >> i) & 1) == 1) {
                reg = reg ^ (poly << (i - 10));
            }
        }
        return ((data << 10) | reg) ^ 0x5412;
    }

    //! BUG FIX: this function previously had row/column swapped for EVERY
    //! format-info bit (verified against the actual working placement logic
    //! of a real, zbar-decodable QR encoder: our computeFormatBits() value
    //! was independently confirmed byte-for-byte correct, but every bit was
    //! being written to modules[8][col] where it needed modules[row][8], and
    //! vice versa). This alone was enough to make every QR we generated
    //! fail to decode on a real scanner while still "looking like" a QR
    //! (finder patterns are unaffected by this bug), which matched exactly
    //! what was reported. Verified independently via a Python
    //! reimplementation, cross-checked module-by-module against a
    //! zbar-decodable reference QR image, until the diff was zero.
    (:qrEncoder)
    private function setFormatBits(modules as ByteArray, n as Number, format as Number) as Void {
        // "Vertical" copy: column 8, split top (bits 0-7) / bottom (bits 8-14)
        for (var i = 0; i <= 14; i++) {
            var bit = (format >> i) & 1;
            if (i < 6) { modules[(i * n) + 8] = bit; }
            else if (i < 8) { modules[((i + 1) * n) + 8] = bit; }
            else { modules[((n - 15 + i) * n) + 8] = bit; }
        }
        // "Horizontal" copy: row 8, split right (bits 0-7) / left (bits 8-14)
        for (var i = 0; i <= 14; i++) {
            var bit = (format >> i) & 1;
            if (i < 8) { modules[(8 * n) + n - i - 1] = bit; }
            else if (i < 9) { modules[(8 * n) + 15 - i] = bit; }
            else { modules[(8 * n) + 14 - i] = bit; }
        }
        modules[((n - 8) * n) + 8] = 1; // dark module, always black
    }

    private const QR_SIZES          = [21, 25, 29, 33];
    private const QR_DATA_CODEWORDS = [19, 34, 55, 80];
    private const QR_EC_CODEWORDS   = [7, 10, 15, 20];
    private const QR_ALIGN_CENTERS  = [0, 18, 22, 26];

    //! Smallest version (index 0-3 for versions 1-4) that holds text at ECC
    //! level L, or -1 when none does. Cheap enough to run on every frame.
    (:qrEncoder)
    private function qrVersionFor(text as String) as Number {
        // Bail out BEFORE doing any encoding work if the text is already too
        // long for version 4 in any mode (byte mode's ceiling is ~78 chars,
        // alphanumeric's is ~114); previously the full bitstream was built
        // first and only checked against capacity afterward, so an
        // unbounded-length input (e.g. a long Barcode Override) could do a
        // lot of avoidable work, or worse, before falling back to text.
        if (text.length() > 120) { return -1; }
        var segmentBits = isAlphanumericQr(text)
            ? 4 + 9 + (11 * (text.length() / 2)) + (6 * (text.length() % 2))
            : 4 + 8 + (8 * text.toUtf8Array().size());
        for (var v = 0; v < QR_DATA_CODEWORDS.size(); v++) {
            if ((QR_DATA_CODEWORDS[v] * 8) >= segmentBits) { return v; }
        }
        return -1;
    }

    //! Data codewords for text at the given version: mode, count, payload,
    //! terminator and pad codewords. The bits are written straight into a
    //! zeroed codeword buffer, with no per-bit array in between.
    (:qrEncoder)
    private function encodeDataCodewords(text as String, versionIdx as Number) as ByteArray {
        var capacityCodewords = QR_DATA_CODEWORDS[versionIdx] as Number;
        var capBits = capacityCodewords * 8;
        var dataCodewords = new [capacityCodewords]b;
        var pos = 0;
        if (isAlphanumericQr(text)) {
            pos = writeBits(dataCodewords, pos, 0x2, 4);
            pos = writeBits(dataCodewords, pos, text.length(), 9);
            var i = 0;
            while (i < text.length()) {
                var a = QR_ALPHANUMERIC.find(text.substring(i, i + 1)) as Number;
                if (i + 1 < text.length()) {
                    var b = QR_ALPHANUMERIC.find(text.substring(i + 1, i + 2)) as Number;
                    pos = writeBits(dataCodewords, pos, (a * 45) + b, 11);
                    i += 2;
                } else {
                    pos = writeBits(dataCodewords, pos, a, 6);
                    i += 1;
                }
            }
        } else {
            var bytes = text.toUtf8Array();
            pos = writeBits(dataCodewords, pos, 0x4, 4);
            pos = writeBits(dataCodewords, pos, bytes.size(), 8);
            for (var i = 0; i < bytes.size(); i++) { pos = writeBits(dataCodewords, pos, bytes[i], 8); }
        }
        // Terminator (up to 4 zero bits) and byte alignment: the buffer is
        // already zeroed, so only the position moves. Then the alternating
        // pad codewords fill the remaining capacity.
        var termLen = capBits - pos;
        if (termLen > 4) { termLen = 4; }
        pos += termLen;
        var padToggle = true;
        for (var c = (pos + 7) / 8; c < capacityCodewords; c++) {
            dataCodewords[c] = padToggle ? 0xEC : 0x11;
            padToggle = !padToggle;
        }
        return dataCodewords;
    }

    (:qrEncoder)
    private function startQrBuild(text as String, key as String, versionIdx as Number) as Void {
        stopQrBuild();
        buildKey     = key;
        buildText    = text;
        buildVersion = versionIdx;
        buildN       = QR_SIZES[versionIdx] as Number;
        buildStage   = 1;
        var timer = new Timer.Timer();
        timer.start(method(:buildStep), 30, true);
        buildTimer = timer;
    }

    (:qrEncoder)
    private function stopQrBuild() as Void {
        if (buildTimer != null) { (buildTimer as Timer.Timer).stop(); }
        buildTimer   = null;
        buildKey     = null;
        buildWords   = null;
        buildModules = null;
        buildIsFn    = null;
        buildStage   = 0;
    }

    //! One stage of the QR build per timer tick, each well inside the
    //! watchdog budget even on the slowest supported watch. The stages run
    //! exactly the steps of a one-shot build, in the same order; only the
    //! two longest loops (data placement and masking) are spread over
    //! several ticks.
    (:qrEncoder)
    function buildStep() as Void {
        var n = buildN;
        if (buildStage == 1) {
            buildWords = encodeDataCodewords(buildText, buildVersion);
            buildStage = 2;
        } else if (buildStage == 2) {
            var dataCodewords = buildWords as ByteArray;
            var capacityCodewords = dataCodewords.size();
            var ecCount = QR_EC_CODEWORDS[buildVersion] as Number;
            var gfExp = buildGfExp();
            var gfLog = buildGfLog(gfExp);
            var ecCodewords = rsComputeRemainder(dataCodewords, ecCount, gfExp, gfLog);
            var allCodewords = new [capacityCodewords + ecCount]b;
            for (var i = 0; i < capacityCodewords; i++) { allCodewords[i] = dataCodewords[i]; }
            for (var i = 0; i < ecCount; i++) { allCodewords[capacityCodewords + i] = ecCodewords[i]; }
            buildWords = allCodewords;
            buildStage = 3;
        } else if (buildStage == 3) {
            var modules = new [n * n]b;
            var isFn = new [n * n]b;
            markFinderArea(modules, isFn, n, 0, 0);
            markFinderArea(modules, isFn, n, n - 7, 0);
            markFinderArea(modules, isFn, n, 0, n - 7);
            drawTimingPatterns(modules, isFn, n);
            reserveFormatAreas(isFn, n);
            if (buildVersion >= 1) {
                drawAlignmentPattern(modules, isFn, n, QR_ALIGN_CENTERS[buildVersion] as Number);
            }
            buildModules  = modules;
            buildIsFn     = isFn;
            buildCol      = n - 1;
            buildBitIndex = 0;
            buildStage    = 4;
        } else if (buildStage == 4) {
            if (placeQrData(buildModules as ByteArray, buildIsFn as ByteArray, n,
                            buildWords as ByteArray, 4)) {
                buildWords = null;
                buildRow   = 0;
                buildStage = 5;
            }
        } else if (buildStage == 5) {
            var toRow = buildRow + 8;
            if (toRow > n) { toRow = n; }
            applyMask0(buildModules as ByteArray, buildIsFn as ByteArray, n, buildRow, toRow);
            buildRow = toRow;
            if (buildRow >= n) { buildStage = 6; }
        } else if (buildStage == 6) {
            var modules = buildModules as ByteArray;
            setFormatBits(modules, n, computeFormatBits());
            cachedKey     = buildKey;
            cachedModules = modules;
            stopQrBuild();
            WatchUi.requestUpdate();
        }
    }


    //! Draw Code 39 at a specific Y coordinate (inline scrollable layout).
    //! Returns the bottom Y of the drawn section (including bottom padding).
    function drawCode39At(dc as Dc, text as String, topY as Number,
                           screenH as Number) as Number {
        var textH = dc.getFontHeight(Graphics.FONT_XTINY);
        var data  = filterCode39(text);
        // Characters Code 39 has no symbol for ('_', '#', accented letters,
        // '*') used to be dropped silently, so the bars encoded a different
        // value from the real ID and a scanner read back the wrong number
        // with nothing on screen to say so. Any value that does not survive
        // the filter intact is now shown as text, with a hint to use QR.
        if (data.length() == 0 || !data.equals(text.toUpper())) {
            return drawTextFallbackAt(dc, text, topY, screenH, HINT_UNSUPPORTED);
        }
        var payload = "*" + data + "*";

        // Use inner width minus side margins to stay inside the circular mask.
        var fullWidth  = dc.getWidth();
        var innerWidth = fullWidth - (2 * SIDE_MARGIN);
        var barH       = dc.getHeight() / 2;
        // Panel is barH + textH + 20 tall; shrink the bars, not the text,
        // when that would not fit below a subscreen.
        if (barH + textH + 20 > maxPanelH) { barH = maxPanelH - textH - 20; }

        var totalUnits = (payload.length() * CHAR_UNITS) - 1 + (2 * QUIET_UNITS);
        var unit = innerWidth / totalUnits;
        // Integer division: unit is the narrow-bar width in whole pixels.
        // Anything under MIN_SCANNABLE_UNIT would draw a barcode that looks
        // plausible but that no scanner can decode (previously unit == 1 was
        // allowed, i.e. hairline bars); show the readable value instead of a
        // barcode that only pretends to work.
        if (unit < MIN_SCANNABLE_UNIT) {
            // Explain the substitution instead of silently swapping bars for
            // text: the user picked a barcode format and got plain text, which
            // reads as a broken app rather than a deliberate decision.
            return drawTextFallbackAt(dc, data, topY, screenH, HINT_USE_QR);
        }

        var panelH = barH + textH + 20;
        if (!checkVisible(topY, panelH, screenH)) {
            return topY + panelH + 60;
        }

        // White panel centred horizontally with side margins
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(SIDE_MARGIN, topY, innerWidth, panelH);

        // Draw bars
        var barcodeWidth = totalUnits * unit;
        var x    = SIDE_MARGIN + ((innerWidth - barcodeWidth) / 2) + (QUIET_UNITS * unit);
        var barY = topY + 6;

        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        for (var c = 0; c < payload.length(); c++) {
            var ch = payload.substring(c, c + 1) as String;
            var charIndex = CODE39_CHARS.find(ch);
            if (charIndex == null) { continue; }
            var pattern = CODE39_PATTERNS[charIndex] as String;
            for (var i = 0; i < 9; i++) {
                var isWide       = pattern.substring(i, i + 1).equals("1");
                var elementWidth = (isWide ? WIDE_RATIO : 1) * unit;
                if ((i % 2) == 0) {
                    dc.fillRectangle(x, barY, elementWidth, barH - 10);
                }
                x += elementWidth;
            }
            x += unit;  // inter-character gap
        }

        // Human-readable value under the bars (standard barcode practice)
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(fullWidth / 2, barY + barH - 6, Graphics.FONT_XTINY, data,
                    Graphics.TEXT_JUSTIFY_CENTER);

        // Extra bottom margin so the user can scroll until the barcode is centred
        return topY + panelH + 60;
    }

    //! Keep only Code 39-encodable characters ('*' is framing-only, excluded).
    private function filterCode39(text as String) as String {
        var upper  = text.toUpper();
        var result = "";
        for (var i = 0; i < upper.length(); i++) {
            var ch = upper.substring(i, i + 1) as String;
            if (!ch.equals("*") && CODE39_CHARS.find(ch) != null) {
                result += ch;
            }
        }
        return result;
    }

    //! White panel with the value as text, used when no scannable code can
    //! be drawn. hint: one of HINT_*. "Switch to QR" is only meaningful on
    //! the Code 39 paths: when QR itself is what failed, the user is already
    //! using it, so that path gets its own message (or none, when there is
    //! nothing actionable to say).
    private function drawTextFallbackAt(dc as Dc, text as String,
                                        topY as Number, screenH as Number,
                                        hint as Number) as Number {
        var fullWidth  = dc.getWidth();
        var innerWidth = fullWidth - (2 * SIDE_MARGIN);
        var textW      = innerWidth - 12;
        var tiny       = Graphics.FONT_XTINY;

        // FONT_SMALL when the value fits on one line, otherwise FONT_XTINY
        // wrapped over as many lines as it needs. It used to be drawn on a
        // single line whatever its length, and a barcode override can be 255
        // characters (QR stops at 120), so most of it ran off the panel.
        var font  = Graphics.FONT_SMALL;
        var lines = [text] as Array<String>;
        if (dc.getTextWidthInPixels(text, font) > textW) {
            font  = tiny;
            lines = TextLayout.wrapLines(dc, text, textW, font);
        }
        var hintLines = [] as Array<String>;
        if (hint != HINT_NONE) {
            var hintText = WatchUi.loadResource(Rez.Strings.barcodeTooLong) as String;
            if (hint == HINT_QR_TOO_LONG) {
                hintText = WatchUi.loadResource(Rez.Strings.barcodeTooLongQr) as String;
            } else if (hint == HINT_UNSUPPORTED) {
                hintText = WatchUi.loadResource(Rez.Strings.barcodeUnsupportedChars) as String;
            } else if (hint == HINT_QR_NO_MEMORY) {
                hintText = WatchUi.loadResource(Rez.Strings.barcodeQrNoMemory) as String;
            }
            hintLines = TextLayout.wrapLines(dc, hintText, textW, tiny);
        }

        var fontH  = dc.getFontHeight(font);
        var tinyH  = dc.getFontHeight(tiny);
        var blockH = (lines.size() * fontH) + (hintLines.size() * tinyH);
        // At least half the screen, as before, but tall enough for the block.
        var panelH = dc.getHeight() / 2;
        if (blockH + 24 > panelH) { panelH = blockH + 24; }
        if (!checkVisible(topY, panelH, screenH)) {
            return topY + panelH + 60;
        }
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(SIDE_MARGIN, topY, innerWidth, panelH);

        // Value and hint centred together as one block, so the value does
        // not sit visually off-centre once the hint is added below it.
        var y = topY + (panelH - blockH) / 2;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < lines.size(); i++) {
            dc.drawText(fullWidth / 2, y, font, lines[i], Graphics.TEXT_JUSTIFY_CENTER);
            y += fontH;
        }
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < hintLines.size(); i++) {
            dc.drawText(fullWidth / 2, y, tiny, hintLines[i], Graphics.TEXT_JUSTIFY_CENTER);
            y += tinyH;
        }
        return topY + panelH + 60;
    }
}
