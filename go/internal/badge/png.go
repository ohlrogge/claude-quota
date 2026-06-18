package badge

import (
	"encoding/binary"
	"hash/crc32"
)

// InjectPhysChunk splices a pHYs chunk (144 dpi, 2× retina) after IHDR so
// SwiftBar renders the PNG at the correct physical size on retina displays.
func InjectPhysChunk(data []byte) []byte {
	const sigLen = 8
	if len(data) < sigLen+12 {
		return data
	}
	ihdrDataLen := int(binary.BigEndian.Uint32(data[sigLen:]))
	insertAt := sigLen + 4 + 4 + ihdrDataLen + 4

	const density uint32 = 5669 // pixels/metre ≈ 144 dpi
	chunkType := []byte("pHYs")
	chunkData := make([]byte, 9)
	binary.BigEndian.PutUint32(chunkData[0:], density)
	binary.BigEndian.PutUint32(chunkData[4:], density)
	chunkData[8] = 1 // unit = metre

	lenBytes := make([]byte, 4)
	binary.BigEndian.PutUint32(lenBytes, uint32(len(chunkData)))

	crcBytes := make([]byte, 4)
	binary.BigEndian.PutUint32(crcBytes,
		crc32.ChecksumIEEE(append(chunkType, chunkData...)))

	chunk := make([]byte, 0, 4+4+9+4)
	chunk = append(chunk, lenBytes...)
	chunk = append(chunk, chunkType...)
	chunk = append(chunk, chunkData...)
	chunk = append(chunk, crcBytes...)

	out := make([]byte, 0, len(data)+len(chunk))
	out = append(out, data[:insertAt]...)
	out = append(out, chunk...)
	out = append(out, data[insertAt:]...)
	return out
}
