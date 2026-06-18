package main

import (
	"bytes"
	"encoding/base64"
	"fmt"
	"image"
	"image/color"
	"image/png"

	"claude-quota/internal/badge"
)

// BarResult is one gauge's input to menuBarImage.
type BarResult struct {
	Name   string
	Usage  *Usage
	HasErr bool
}

// Badge geometry (all measurements in pixels at 2× retina scale).
const (
	badgeW    = 52 // fixed badge width
	gaugeH    = 28 // badge height (retained name; used in menuBarImage)
	badgeR    = 5  // corner radius
	starZoneW = 18 // left zone reserved for the * glyph
	numZoneW  = 34 // right zone for the number / countdown
)

// drawBadge renders a solid rounded badge at (x, y).
//
// Normally the badge is split into two zones: the left zone shows * (the Claude
// icon shorthand) and the right zone shows the utilization number. On error, !
// replaces the number; * stays in place.
//
// When a countdown is shown (text set, e.g. "4:28" / "7D") it is too wide for
// the right zone, so the * is dropped and the time is centred across the whole
// badge. The countdown only appears in the visually-distinct 100%/lockout state,
// so the * is not needed to identify the badge there.
// fillC overrides the automatic background colour (used for the weekly-lockout black fill).
func drawBadge(img *image.NRGBA, x, y int, utilization *float64, hasErr bool, text string, fillC *color.NRGBA) {
	// Resolve background colour.
	var bg color.NRGBA
	if hasErr {
		bg = badge.ColorErrOutline
	} else if fillC != nil {
		bg = *fillC
	} else if utilization != nil {
		u := *utilization
		switch {
		case u >= 90:
			bg = badge.ColorRed
		case u >= 75:
			bg = badge.ColorOrange
		case u >= 60:
			bg = badge.ColorYellow
		default:
			bg = badge.ColorGreen
		}
	} else {
		bg = badge.ColorGreen
	}

	// 1. Solid filled badge.
	badge.DrawFilledRoundedRect(img, x, y, x+badgeW, y+gaugeH, badgeR, bg)

	glyphY := y + (gaugeH-14)/2

	// A countdown is wider than the right zone, so it takes over the whole badge.
	showTime := !hasErr && text != ""

	// * centred in the left zone — omitted when a countdown takes the full width.
	if !showTime {
		starX := x + (starZoneW-10)/2
		badge.DrawLetter(img, starX, glyphY, '*', badge.ColorWhite, 2)
	}

	// Number, ! or countdown.
	var numStr string
	if hasErr {
		numStr = "!"
	} else if utilization == nil {
		return
	} else {
		numStr = text
		if numStr == "" {
			numStr = fmt.Sprintf("%.0f", *utilization)
		}
	}
	runes := []rune(numStr)
	numTextW := len(runes)*10 + max(0, len(runes)-1)*2

	// Centre the time across the whole badge; otherwise centre in the right zone.
	tx := x + starZoneW + (numZoneW-numTextW)/2
	if showTime {
		tx = x + (badgeW-numTextW)/2
	}
	for _, ch := range runes {
		badge.DrawLetter(img, tx, glyphY, ch, badge.ColorWhite, 2)
		tx += 12
	}
}

// menuBarImage renders all visible badges as a retina-ready base64 PNG.
// Each badge is a solid coloured rounded rect with * on the left and the
// utilization percentage (or countdown) on the right.
func menuBarImage(results []BarResult, showLetters bool) (string, error) {
	const (
		letterW = 10
		gap     = 4
		cellGap = 8
		height  = 32
		gaugeY  = (height - gaugeH) / 2 // centres the 24 px badge in the 32 px canvas
	)

	n := len(results)
	labelW := 0
	if showLetters {
		labelW = letterW + gap
	}
	cellW := labelW + badgeW

	width := 0
	if n > 0 {
		width = n*cellW + (n-1)*cellGap
	}

	img := image.NewNRGBA(image.Rect(0, 0, width, height))

	for i, r := range results {
		x := i * (cellW + cellGap)

		var util *float64
		var text string
		var fillC *color.NRGBA

		if r.Usage != nil {
			five := r.Usage.FiveHour
			week := r.Usage.SevenDay

			if five != nil {
				v := five.Utilization
				util = &v
			}
			if week != nil && week.Utilization >= 100 {
				v := 100.0
				util = &v
				c := badge.ColorBlack
				fillC = &c
				if cd := badge.Countdown(week.ResetsAt); cd != "" {
					text = cd
				}
			} else if five != nil && five.Utilization >= 100 {
				if cd := badge.Countdown(five.ResetsAt); cd != "" {
					text = cd
				}
			}
		}

		if showLetters {
			if runes := []rune(r.Name); len(runes) > 0 {
				badge.DrawLetter(img, x, (height-14)/2, runes[0], badge.ColorWhite, 2)
			}
		}
		drawBadge(img, x+labelW, gaugeY, util, r.HasErr, text, fillC)
	}

	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		return "", err
	}
	return base64.StdEncoding.EncodeToString(badge.InjectPhysChunk(buf.Bytes())), nil
}
