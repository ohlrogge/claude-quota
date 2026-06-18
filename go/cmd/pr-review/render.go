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

// Badge geometry (pixels at 2× retina scale), matching the claude-quota badge.
const (
	badgeW    = 52
	badgeH    = 28
	badgeR    = 5
	glyphZone = 18 // left zone for the R glyph
	numZone   = 34 // right zone for the count / !
)

// countColor escalates with how many reviews are waiting on you.
func countColor(n int) color.NRGBA {
	switch {
	case n == 0:
		return badge.ColorGray
	case n >= 5:
		return badge.ColorRed
	case n >= 3:
		return badge.ColorOrange
	default:
		return badge.ColorBlue
	}
}

// menuBarImage renders a single badge: an R glyph on the left and the
// review-requested count (or ! on error) on the right.
func menuBarImage(count int, hasErr bool) (string, error) {
	const (
		height = 32
		badgeY = (height - badgeH) / 2
	)

	img := image.NewNRGBA(image.Rect(0, 0, badgeW, height))

	bg := countColor(count)
	if hasErr {
		bg = badge.ColorErrOutline
	}
	badge.DrawFilledRoundedRect(img, 0, badgeY, badgeW, badgeY+badgeH, badgeR, bg)

	glyphY := badgeY + (badgeH-14)/2

	// Branch glyph centred in the left zone.
	badge.DrawGlyph(img, (glyphZone-10)/2, glyphY, "BRANCH", badge.ColorWhite, 2)

	// Count or ! centred in the right zone.
	numStr := fmt.Sprintf("%d", count)
	if hasErr {
		numStr = "!"
	}
	runes := []rune(numStr)
	numTextW := len(runes)*10 + max(0, len(runes)-1)*2
	tx := glyphZone + (numZone-numTextW)/2
	for _, ch := range runes {
		badge.DrawLetter(img, tx, glyphY, ch, badge.ColorWhite, 2)
		tx += 12
	}

	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		return "", err
	}
	return base64.StdEncoding.EncodeToString(badge.InjectPhysChunk(buf.Bytes())), nil
}
