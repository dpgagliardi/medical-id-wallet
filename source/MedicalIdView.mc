// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Daniele Gagliardi
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version. See LICENSE for details.

import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Attention;
import Toybox.System;

class MedicalIdView extends WatchUi.View {
    private var model           as MedicalIdModel;
    private var barcodeRenderer as BarcodeRenderer;

    private const COLOR_BLACK    = 0x000000;
    private const COLOR_WHITE    = 0xFFFFFF;
    private const COLOR_RED_NEON = 0xFF0000;
    private const COLOR_GREY     = 0xAAAAAA;

    //! Set on the base view of a widget whose up/down buttons belong to the
    //! carousel: without a cue, that screen looks like the whole app and the
    //! rest of the profile is unreachable. "START" is the physical button
    //! label on Garmin wearables, so it needs no translation.
    private var showOpenHint as Boolean;

    function initialize(model as MedicalIdModel, showOpenHint as Boolean) {
        View.initialize();
        self.model = model;
        self.showOpenHint = showOpenHint;
        barcodeRenderer = new BarcodeRenderer();
    }

    function onLayout(dc as Dc) as Void {}

    function onUpdate(dc as Dc) as Void {
        dc.setColor(COLOR_WHITE, COLOR_BLACK);
        dc.clear();
        var backlightOn = false;
        try {
            backlightOn = drawMainScreen(dc);
        } catch (ex) {
            // Render aborted partway through: avoid leaving a stuck black
            // frame; reset scroll so the next update starts from a known-good state.
            // Deliberately NO requestUpdate() here: if the failure is
            // deterministic (and it would be, since the barcode is part of
            // every frame) requesting another update from inside the failure
            // handler produces an unbounded onUpdate -> throw -> requestUpdate
            // loop that pins the CPU and leaves the widget stuck. The next
            // real user interaction redraws anyway.
            model.setScrollOffset(0);
            dc.setColor(COLOR_WHITE, COLOR_BLACK);
            dc.clear();
            dc.setColor(COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, Graphics.FONT_SMALL,
                "..", Graphics.TEXT_JUSTIFY_CENTER);
        }
        // Only ever request backlight ON when the barcode is visible.
        // Attention.backlight() "always respect[s] the backlight timeout
        // settings on the device" (per the SDK docs), so it turns itself
        // off naturally: an explicit backlight(false) call was causing a
        // black-frame glitch on some devices (e.g. Forerunner 170) both
        // when scrolling the barcode out of view and when closing the
        // widget via Back.
        if (backlightOn) {
            setBacklight(true);
        }
        if (showOpenHint && model.hasData()) {
            drawOpenHint(dc);
        }
    }

    //! Bottom-of-screen cue drawn over the content, telling the wearer the
    //! profile continues behind a button press. Drawn last so scrolled
    //! content cannot paint over it.
    private function drawOpenHint(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var hintH = dc.getFontHeight(Graphics.FONT_XTINY);
        // Band is taller than the label so a content line ending just above
        // it is covered outright rather than left half-drawn.
        var bandY = h - hintH - 12;
        dc.setColor(COLOR_BLACK, COLOR_BLACK);
        dc.fillRectangle(0, bandY, w, h - bandY);

        // "START" is printed on the hardware, so it stays untranslated; the
        // verb around it is localized. Longer languages (hu, fr) can outrun
        // a narrow round screen, so fall back to the bare button name rather
        // than let the cue run under the bezel.
        var label = WatchUi.loadResource(Rez.Strings.pressStart) as String;
        if (dc.getTextWidthInPixels(label, Graphics.FONT_XTINY) > w - 8) {
            label = "START";
        }
        dc.setColor(COLOR_GREY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, bandY + 4, Graphics.FONT_XTINY, label,
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Gap between two fields in the compact layout.
    private const FIELD_GAP = 6;

    // Per-frame layout state, filled while drawing and handed to the model at
    // the end so scrolling can stop on field boundaries (see
    // MedicalIdModel.setScrollStops). Content coordinates, i.e. independent
    // of the current scroll offset.
    private var stopOffsets  as Array<Number> = [] as Array<Number>;
    private var blockBottoms as Array<Number> = [] as Array<Number>;

    // Single scrollable screen: ICE info followed by barcode inline.
    // Returns true when the barcode panel is in the viewport (activates backlight).
    //
    // Compact layout: a field is "LABEL: value" on one line instead of a
    // label line over a value line, which roughly halved the height of the
    // short fields; wearers had reported needing too many DOWN presses.
    // Values that must never be split (phone numbers, IDs, dates) fall back
    // to the stacked layout when they do not fit beside their label, and are
    // only ever broken by character when wider than the screen on their own.
    private function drawMainScreen(dc as Dc) as Boolean {
        var width   = dc.getWidth();
        var height  = dc.getHeight();
        var centerX = width / 2;

        // Empty state: no data configured yet. Previously the two hint
        // lines were hardcoded English text, never localized; fixed here,
        // plus a third line suggesting the minimum recommended fields so a
        // first-time user isn't left guessing where to start.
        if (!model.hasData()) {
            drawEmptyState(dc);
            return false;
        }

        var scrollOffset = model.getScrollOffset();
        var isRound = System.getDeviceSettings().screenShape == System.SCREEN_SHAPE_ROUND;

        var topMargin = height > 400 ? 35 : 45;
        // Round displays lose usable width near the very top edge (chord
        // width shrinks toward the bezel curve); push content down a bit
        // further so the first label isn't clipped by the circular mask.
        if (isRound) {
            topMargin += 15;
        }
        stopOffsets  = [] as Array<Number>;
        blockBottoms = [] as Array<Number>;

        var yPos  = topMargin - scrollOffset;
        var tiny  = Graphics.FONT_XTINY;
        var small = Graphics.FONT_SMALL;
        var maxW  = width * 3 / 4;
        var start;

        // Name: one line when it fits, otherwise first and last name on
        // separate lines, since long full names (e.g. double surnames) can
        // overflow the screen width on one line
        var firstName = model.getFirstName();
        var lastName  = model.getLastName();
        if (firstName != null || lastName != null) {
            start = yPos;
            dc.setColor(COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            var smallH = dc.getFontHeight(small);
            var full = (firstName != null && lastName != null)
                ? (firstName as String) + " " + (lastName as String) : null;
            if (full != null && dc.getTextWidthInPixels(full, small) <= maxW) {
                dc.drawText(centerX, yPos, small, full, Graphics.TEXT_JUSTIFY_CENTER);
                yPos += smallH;
            } else {
                if (firstName != null) {
                    dc.drawText(centerX, yPos, small, firstName as String, Graphics.TEXT_JUSTIFY_CENTER);
                    yPos += smallH;
                }
                if (lastName != null) {
                    dc.drawText(centerX, yPos, small, lastName as String, Graphics.TEXT_JUSTIFY_CENTER);
                    yPos += smallH;
                }
            }
            yPos = endBlock(start, yPos, scrollOffset, topMargin) + FIELD_GAP;
        }

        // Blood type: critical for transfusion decisions, kept visually
        // prominent (red box). Its label sits beside the box when both fit.
        var bloodType = model.getBloodType();
        if (bloodType != null) {
            start = yPos;
            var label = WatchUi.loadResource(Rez.Strings.bloodTypeLabel) as String;
            var tinyH = dc.getFontHeight(tiny);
            var boxH  = dc.getFontHeight(Graphics.FONT_MEDIUM) + 4;
            var boxW  = dc.getTextWidthInPixels(bloodType, Graphics.FONT_MEDIUM) + 24;
            var labelW = dc.getTextWidthInPixels(label, tiny);
            var boxX;
            if (labelW + 8 + boxW <= maxW) {
                var x0 = centerX - (labelW + 8 + boxW) / 2;
                dc.setColor(COLOR_GREY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(x0, yPos + (boxH - tinyH) / 2, tiny, label, Graphics.TEXT_JUSTIFY_LEFT);
                boxX = x0 + labelW + 8;
            } else {
                dc.setColor(COLOR_GREY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(centerX, yPos, tiny, label, Graphics.TEXT_JUSTIFY_CENTER);
                yPos += tinyH + 1;
                boxX = centerX - boxW / 2;
            }
            dc.setColor(COLOR_RED_NEON, COLOR_RED_NEON);
            dc.fillRoundedRectangle(boxX, yPos, boxW, boxH, 6);
            dc.setColor(COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(boxX + boxW / 2, yPos + 2, Graphics.FONT_MEDIUM, bloodType,
                Graphics.TEXT_JUSTIFY_CENTER);
            yPos = endBlock(start, yPos + boxH, scrollOffset, topMargin) + FIELD_GAP;
        }

        // Age: computed from DOB; responders need age faster than an exact
        // birth date for triage/dosing decisions
        var age = model.getAge();
        if (age != null) {
            yPos = drawField(dc, yPos, Rez.Strings.ageLabel, age as String, true,
                             scrollOffset, topMargin);
        }

        // National / Health ID: identity/insurance lookup
        var nationalId = model.getNationalId();
        if (nationalId != null) {
            yPos = drawField(dc, yPos, Rez.Strings.nationalIdLabel, nationalId, true,
                             scrollOffset, topMargin);
        }

        // Allergies: must be known before administering anything
        var allergies = model.getAllergies();
        if (allergies != null) {
            yPos = drawField(dc, yPos, Rez.Strings.allergiesLabel, allergies, false,
                             scrollOffset, topMargin);
        }

        // Medications: interaction risk, needed right after allergies
        var medications = model.getMedications();
        if (medications != null) {
            yPos = drawField(dc, yPos, Rez.Strings.medicationsLabel, medications, false,
                             scrollOffset, topMargin);
        }

        // Medical conditions: context for symptoms
        var cond = model.getConditions();
        if (cond != null) {
            yPos = drawField(dc, yPos, Rez.Strings.conditionsLabel, cond, false,
                             scrollOffset, topMargin);
        }

        // Height · Weight: secondary, useful for dosing/imaging
        var physical = model.getPhysicalInfo();
        if (physical != null) {
            start = yPos;
            dc.setColor(COLOR_GREY, Graphics.COLOR_TRANSPARENT);
            yPos += dc.getFontHeight(tiny) * drawWrappedText(dc, physical, centerX, yPos, maxW, tiny);
            yPos = endBlock(start, yPos, scrollOffset, topMargin) + FIELD_GAP;
        }

        // Emergency contacts: name + relationship shown with the number,
        // since a bare phone number is nearly useless to a responder who
        // doesn't know if it's a spouse, parent, or a random contact
        var hasC1 = model.getIceContact1() != null || model.getIceContact1Name() != null
                    || model.getIceContact1Rel() != null;
        var hasC2 = model.getIceContact2() != null || model.getIceContact2Name() != null
                    || model.getIceContact2Rel() != null;
        if (hasC1 || hasC2) {
            start = yPos;
            dc.setColor(COLOR_GREY, Graphics.COLOR_TRANSPARENT);
            yPos += dc.getFontHeight(tiny) * drawWrappedText(dc,
                WatchUi.loadResource(Rez.Strings.contactsLabel) as String,
                centerX, yPos, maxW, tiny);
            // The heading travels with the first contact, so a stop never
            // leaves it alone at the bottom of a screen.
            if (hasC1) {
                yPos = drawContact(dc, yPos, model.getIceContact1Name(),
                                   model.getIceContact1Rel(), model.getIceContact1());
                yPos = endBlock(start, yPos, scrollOffset, topMargin);
                start = yPos;
            }
            if (hasC2) {
                yPos = drawContact(dc, yPos, model.getIceContact2Name(),
                                   model.getIceContact2Rel(), model.getIceContact2());
                yPos = endBlock(start, yPos, scrollOffset, topMargin);
            }
            yPos += FIELD_GAP;
        }

        // Organ donor status: secondary
        var donor = model.getDonorStatus();
        if (donor != 0) {
            var donorText = donor == 1
                ? WatchUi.loadResource(Rez.Strings.donorYes) as String
                : WatchUi.loadResource(Rez.Strings.donorNo) as String;
            yPos = drawField(dc, yPos, Rez.Strings.donorStatusLabel, donorText, true,
                             scrollOffset, topMargin);
        }

        // Date of birth: exact date kept for reference, after the computed age
        var dob = model.getDateOfBirth();
        if (dob != null) {
            yPos = drawField(dc, yPos, Rez.Strings.dateOfBirthLabel, dob as String, true,
                             scrollOffset, topMargin);
        }

        // Barcode inline: appended after all text fields. Dispatches on the
        // user's selected format (None/QR/Code39); both use the same simple
        // National ID / Barcode Override content.
        // The renderer decides visibility itself and skips the (expensive)
        // module/bar drawing when the panel is off screen, then reports back
        // whether it was on screen. The view used to estimate the panel
        // height here to make that call, but its estimate never matched what
        // the QR path actually produces, so the backlight could fire while
        // the code was still off screen (or not at all).
        var barcodeVisible = false;
        var barcodeStop = 0;
        if (model.hasDocument()) {
            yPos += 12;
            var content = model.getBarcodeContent();
            if (content != null) {
                start = yPos;
                // Optional caption: without it the panel is a bare code, and
                // neither the wearer nor a responder can tell whether it is a
                // race bib, an insurance number or a health-profile link.
                var docLabel = model.getDocLabel();
                if (docLabel != null) {
                    dc.setColor(COLOR_GREY, Graphics.COLOR_TRANSPARENT);
                    yPos += dc.getFontHeight(tiny) * drawWrappedText(dc, docLabel as String,
                                                     centerX, yPos, maxW, tiny) + 4;
                }
                yPos = barcodeRenderer.drawBarcodeAt(dc, model.getDocType(),
                                                      content as String, yPos, height);
                barcodeVisible = barcodeRenderer.isLastBarcodeVisible();
                // The renderer's return value includes 60px of bottom padding.
                var panelBottom = yPos - 60;
                var blockH = panelBottom - start;
                // The stop for the code centres caption + panel on screen,
                // which is where it is scanned from, rather than pinning it to
                // the top margin like a text field.
                barcodeStop = blockH < height
                    ? start + scrollOffset - (height - blockH) / 2
                    : start + scrollOffset - topMargin;
                if (barcodeStop < 0) { barcodeStop = 0; }
                stopOffsets.add(barcodeStop);
                blockBottoms.add(panelBottom + scrollOffset);
            }
        }

        // Update max scroll so DOWN key stops at the bottom; never short of
        // the barcode's own stop, or a centred code could not be reached.
        var maxScroll = yPos + scrollOffset - height + 10;
        if (barcodeStop > maxScroll) { maxScroll = barcodeStop; }
        model.setMaxScroll(maxScroll);
        // Content near a round bezel is clipped, so a block that close to the
        // bottom edge does not count as fully visible.
        model.setScrollStops(stopOffsets, blockBottoms, height,
                             isRound ? height / 10 : 8, topMargin);

        return barcodeVisible;
    }

    //! Records a block (a field or group that should never be cut by a scroll
    //! stop) and returns its bottom, for chaining into the next yPos.
    private function endBlock(top as Number, bottom as Number, scrollOffset as Number,
                              topMargin as Number) as Number {
        stopOffsets.add(top + scrollOffset - topMargin);
        blockBottoms.add(bottom + scrollOffset);
        return bottom;
    }

    //! Draws "LABEL: value" and returns the y below it (gap included).
    //! atomic: the value must not be split between words (phone numbers,
    //! IDs, dates). If it does not fit beside the label it moves to its own
    //! line under it, and is broken by character only when wider than the
    //! line by itself. Free text wraps between words, starting right after
    //! the label.
    private function drawField(dc as Dc, y as Number, labelId as ResourceId,
                               value as String, atomic as Boolean,
                               scrollOffset as Number, topMargin as Number) as Number {
        var start   = y;
        var tiny    = Graphics.FONT_XTINY;
        var lineH   = dc.getFontHeight(tiny);
        var centerX = dc.getWidth() / 2;
        var maxW    = dc.getWidth() * 3 / 4;
        var label   = WatchUi.loadResource(labelId) as String;
        var inline  = label + " " + value;

        if (atomic) {
            if (dc.getTextWidthInPixels(inline, tiny) <= maxW) {
                drawTwoTone(dc, y, label, " " + value);
                y += lineH;
            } else {
                y = drawStacked(dc, y, label, TextLayout.wrapAtomic(dc, value, maxW, tiny));
            }
        } else {
            var lines = TextLayout.wrapLines(dc, inline, maxW, tiny);
            var first = lines[0];
            if (first.length() >= label.length()
                    && first.substring(0, label.length()).equals(label)) {
                drawTwoTone(dc, y, label, first.substring(label.length(), first.length()) as String);
                y += lineH;
                dc.setColor(COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                for (var i = 1; i < lines.size(); i++) {
                    dc.drawText(centerX, y, tiny, lines[i], Graphics.TEXT_JUSTIFY_CENTER);
                    y += lineH;
                }
            } else {
                // The label itself was broken across lines (a long
                // translation on a narrow screen): stack instead.
                y = drawStacked(dc, y, label, TextLayout.wrapLines(dc, value, maxW, tiny));
            }
        }
        return endBlock(start, y, scrollOffset, topMargin) + FIELD_GAP;
    }

    //! Grey label line, then the given value lines in white.
    private function drawStacked(dc as Dc, y as Number, label as String,
                                 lines as Array<String>) as Number {
        var tiny    = Graphics.FONT_XTINY;
        var lineH   = dc.getFontHeight(tiny);
        var centerX = dc.getWidth() / 2;
        dc.setColor(COLOR_GREY, Graphics.COLOR_TRANSPARENT);
        y += lineH * drawWrappedText(dc, label, centerX, y, dc.getWidth() * 3 / 4, tiny);
        dc.setColor(COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < lines.size(); i++) {
            dc.drawText(centerX, y, tiny, lines[i], Graphics.TEXT_JUSTIFY_CENTER);
            y += lineH;
        }
        return y;
    }

    //! One centred line: grey label immediately followed by white text.
    private function drawTwoTone(dc as Dc, y as Number, label as String, rest as String) as Void {
        var tiny   = Graphics.FONT_XTINY;
        var labelW = dc.getTextWidthInPixels(label, tiny);
        var x0     = dc.getWidth() / 2 - (labelW + dc.getTextWidthInPixels(rest, tiny)) / 2;
        dc.setColor(COLOR_GREY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x0, y, tiny, label, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x0 + labelW, y, tiny, rest, Graphics.TEXT_JUSTIFY_LEFT);
    }

    //! "Jane Doe (Spouse) +1 555 0101" on one line when it fits. Otherwise
    //! the name wraps freely and the number goes on its own line, whole: a
    //! number split across two lines is easy to dial half of.
    private function drawContact(dc as Dc, y as Number, name as String?,
                                 relation as String?, phone as String?) as Number {
        var tiny    = Graphics.FONT_XTINY;
        var lineH   = dc.getFontHeight(tiny);
        var centerX = dc.getWidth() / 2;
        var maxW    = dc.getWidth() * 3 / 4;
        var who     = contactDisplayLine(name, relation, null);
        dc.setColor(COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var full = contactDisplayLine(name, relation, phone);
        if (full != null && dc.getTextWidthInPixels(full as String, tiny) <= maxW) {
            dc.drawText(centerX, y, tiny, full as String, Graphics.TEXT_JUSTIFY_CENTER);
            return y + lineH;
        }
        if (who != null) {
            y += lineH * drawWrappedText(dc, who as String, centerX, y, maxW, tiny);
        }
        if (phone != null) {
            var lines = TextLayout.wrapAtomic(dc, phone as String, maxW, tiny);
            for (var i = 0; i < lines.size(); i++) {
                dc.drawText(centerX, y, tiny, lines[i], Graphics.TEXT_JUSTIFY_CENTER);
                y += lineH;
            }
        }
        return y;
    }

    //! Empty state: no data configured yet. The lines used to sit at fixed
    //! offsets from the centre (-40, -5, +12, +34 px) whatever the font size,
    //! so on high-resolution AMOLED screens, where FONT_XTINY alone is taller
    //! than those gaps, they overlapped; and unwrapped, the longer
    //! translations ran under the bezel. Now each line is wrapped and the
    //! block is stacked by real font height, then centred as a whole.
    private function drawEmptyState(dc as Dc) as Void {
        var width   = dc.getWidth();
        var centerX = width / 2;
        var maxW    = width * 3 / 4;
        var tiny    = Graphics.FONT_XTINY;
        var small   = Graphics.FONT_SMALL;
        var texts = [
            WatchUi.loadResource(Rez.Strings.noData) as String,
            WatchUi.loadResource(Rez.Strings.openConnectMobile) as String,
            WatchUi.loadResource(Rez.Strings.setupProfileHint) as String,
            WatchUi.loadResource(Rez.Strings.minimumFieldsHint) as String
        ] as Array<String>;
        var fonts  = [small, tiny, tiny, tiny] as Array<FontType>;
        var colors = [COLOR_WHITE, COLOR_GREY, COLOR_GREY, COLOR_RED_NEON] as Array<Number>;
        // Gap after each block: a wider one separates the title from the hints.
        var gaps   = [8, 0, 6, 0] as Array<Number>;

        var blockH = 0;
        for (var i = 0; i < texts.size(); i++) {
            blockH += TextLayout.wrapLines(dc, texts[i], maxW, fonts[i]).size()
                      * dc.getFontHeight(fonts[i]) + gaps[i];
        }
        var y = (dc.getHeight() - blockH) / 2;
        for (var i = 0; i < texts.size(); i++) {
            dc.setColor(colors[i], Graphics.COLOR_TRANSPARENT);
            y += TextLayout.drawWrapped(dc, texts[i], centerX, y, maxW, fonts[i])
                 * dc.getFontHeight(fonts[i]) + gaps[i];
        }
    }

    //! "Jane Doe (Spouse) +1 555 0101": a bare phone number tells a
    //! responder nothing about who to call or why; name + relationship do.
    private function contactDisplayLine(name as String?, relation as String?,
                                         phone as String?) as String? {
        var line = "";
        if (name != null) { line += name as String; }
        if (relation != null) {
            line += (line.length() > 0 ? " (" : "(") + (relation as String) + ")";
        }
        if (phone != null) { line += (line.length() > 0 ? " " : "") + (phone as String); }
        return line.length() > 0 ? line : null;
    }

    private function setBacklight(enabled as Boolean) as Void {
        if (Attention has :backlight) {
            try { Attention.backlight(enabled); } catch (ex) {}
        }
    }

    private function drawWrappedText(dc as Dc, text as String, cx as Number,
                                     y as Number, maxW as Number,
                                     font as FontType) as Number {
        return TextLayout.drawWrapped(dc, text, cx, y, maxW, font);
    }

    //! The base view and the pushed view share one model, so the scroll
    //! position the pushed view was left at would otherwise still be applied
    //! when the user backs out to the base view, which then shows the
    //! middle of the profile behind the "press START" cue instead of the
    //! summary it is meant to be.
    function onShow() as Void {
        if (showOpenHint) { model.setScrollOffset(0); }
    }
    // No explicit backlight(false) here: Attention.backlight() already
    // respects the device's own timeout, and forcing it off while the view
    // is closing was the source of a black-frame glitch on some devices.
    function onHide() as Void {}
}
