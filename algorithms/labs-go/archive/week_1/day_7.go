package week1

// 76. Minimum Window Substring https://leetcode.com/problems/minimum-window-substring/description/
func MinWindow(s string, t string) string {
	if len(s) < len(t) {
		return ""
	}

	// 1. Setup: Target Frequency Map (T)
	targetFreq := make(map[byte]int)
	for i := 0; i < len(t); i++ {
		targetFreq[t[i]]++
	}

	required := len(targetFreq) // Number of unique chars we need to match
	matched := 0                // Number of unique chars whose count is met

	// Result tracking variables
	minLen := len(s) + 1 // Start with a length larger than s
	startIndex := 0

	left := 0

	// We use one map to track the current window's content (relative to target)
	windowCounts := make(map[byte]int)

	// --- Expansion Phase (Outer Loop) ---
	for right := 0; right < len(s); right++ {
		charR := s[right]

		// 1a. Update window counts for the character added by 'right'
		windowCounts[charR]++

		// 1b. Check if this character helps meet the required count
		// Note: We only check if the character is one T needs.
		if countT, exists := targetFreq[charR]; exists {
			if windowCounts[charR] == countT {
				matched++ // We just satisfied the count for this specific unique character
			}
		}

		// --- Contraction Phase (Inner Loop) ---
		// 2. Try to shrink the window if the current window is valid
		for matched == required {
			// 2a. Record the current minimum window
			currentLen := right - left + 1
			if currentLen < minLen {
				minLen = currentLen
				startIndex = left // Record the start of this smallest valid window
			}

			// 2b. Shrink the window: remove the character at 'left'
			charL := s[left]
			windowCounts[charL]--

			// 2c. Check if removing this character violates the required count
			if countT, exists := targetFreq[charL]; exists {
				if windowCounts[charL] < countT {
					matched-- // We lost the match for this unique character, breaking the validity
				}
			}

			left++ // Always move the left pointer forward
		}
	}

	// 3. Final Result: If minLen was never updated, no window was found.
	if minLen > len(s) {
		return ""
	}
	return s[startIndex : startIndex+minLen]
}
