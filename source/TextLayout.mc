// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Daniele Gagliardi
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version. See LICENSE for details.
// Additional attribution terms (GPL-3.0 section 7(b)): see NOTICE.

import Toybox.Graphics;
import Toybox.Lang;

//! Word wrapping shared by the main view and the barcode fallback panel.
//! It lived inside MedicalIdView, so the barcode fallback drew its value on
//! one line and a long override code ran past the panel edges.
module TextLayout {

    //! Splits text into the lines that will actually be rendered.
    //! Single source of truth for drawing and for height measurement: these
    //! were two separate implementations, and the measuring one hardcoded
    //! FONT_XTINY regardless of the font it was given; any divergence
    //! between them silently offset every field below it.
    //! A word wider than maxW is broken character-by-character rather than
    //! drawn past the screen edge: a long unbroken medication or allergen
    //! name used to have its tail clipped away with no indication.
    function wrapLines(dc as Dc, text as String, maxW as Number,
                       font as FontType) as Array<String> {
        var lines = [] as Array<String>;
        var words = splitWords(text);
        var line  = "";
        for (var i = 0; i < words.size(); i++) {
            var w = words[i];
            while (dc.getTextWidthInPixels(w, font) > maxW && w.length() > 1) {
                var fit = 1;
                while (fit < w.length() && dc.getTextWidthInPixels(
                        w.substring(0, fit + 1) as String, font) <= maxW) {
                    fit++;
                }
                if (line.length() > 0) { lines.add(line); line = ""; }
                lines.add(w.substring(0, fit) as String);
                w = w.substring(fit, w.length()) as String;
            }
            var test = line.length() == 0 ? w : line + " " + w;
            if (dc.getTextWidthInPixels(test, font) > maxW && line.length() > 0) {
                lines.add(line);
                line = w;
            } else {
                line = test;
            }
        }
        if (line.length() > 0) { lines.add(line); }
        return lines;
    }

    //! Lines for a value that must not be split between words: a phone
    //! number or an ID broken at a space reads as two separate values (and a
    //! responder may dial only the first half). Returned whole when it fits,
    //! otherwise broken by character only, as late as possible.
    function wrapAtomic(dc as Dc, text as String, maxW as Number,
                        font as FontType) as Array<String> {
        if (dc.getTextWidthInPixels(text, font) <= maxW) { return [text] as Array<String>; }
        var lines = [] as Array<String>;
        var rest  = text;
        while (rest.length() > 0) {
            var fit = 1;
            while (fit < rest.length() && dc.getTextWidthInPixels(
                    rest.substring(0, fit + 1) as String, font) <= maxW) {
                fit++;
            }
            lines.add(rest.substring(0, fit) as String);
            rest = rest.substring(fit, rest.length()) as String;
        }
        return lines;
    }

    function splitWords(text as String) as Array<String> {
        var words     = [] as Array<String>;
        var remaining = text;
        while (remaining.length() > 0) {
            var idx = remaining.find(" ");
            if (idx == null) {
                words.add(remaining);
                remaining = "";
            } else {
                var w = remaining.substring(0, idx) as String;
                if (w.length() > 0) { words.add(w); }
                remaining = remaining.substring(idx + 1, remaining.length()) as String;
            }
        }
        return words;
    }

    //! Draws the text wrapped and centred on cx, and returns how many lines it
    //! occupied, so the caller can advance its y without wrapping twice.
    function drawWrapped(dc as Dc, text as String, cx as Number, y as Number,
                         maxW as Number, font as FontType) as Number {
        var lines = wrapLines(dc, text, maxW, font);
        var lineH = dc.getFontHeight(font);
        for (var i = 0; i < lines.size(); i++) {
            dc.drawText(cx, y, font, lines[i] as String, Graphics.TEXT_JUSTIFY_CENTER);
            y += lineH;
        }
        return lines.size();
    }
}
