package week7

import "log"

// 200. Number of Islands https://leetcode.com/problems/number-of-islands/description/

func NumIslands(grid [][]byte) int {
	ROWS := len(grid)
	COLS := len(grid[0])
	visited := make(map[[2]int]bool, 0)
	res := 0
	var dfs func(r, c int)
	dfs = func(r, c int) {
		if r == ROWS || r < 0 || c == COLS || c < 0 || grid[r][c] == '0' || visited[[2]int{r, c}] {
			return
		}
		visited[[2]int{r, c}] = true
		dfs(r-1, c)
		dfs(r, c+1)
		dfs(r+1, c)
		dfs(r, c-1)
	}
	for i := 0; i < ROWS; i++ {
		for j := 0; j < COLS; j++ {
			if !visited[[2]int{i, j}] && grid[i][j] == '1' {
				dfs(i, j)
				res++
			}
		}
	}
	return res
}

// 733. Flood Fill https://leetcode.com/problems/flood-fill/description/
func FloodFill(image [][]int, sr int, sc int, color int) [][]int {
	ROWS := len(image)
	COLS := len(image[0])
	source := image[sr][sc]
	if source == color {
		return image
	}
	var dfs func(r, c int)
	dfs = func(r, c int) {
		log.Println("haha", r, c)
		if r == ROWS || r < 0 || c == COLS || c < 0 || image[r][c] != source {
			return
		}
		image[r][c] = color
		dfs(r-1, c)
		dfs(r, c+1)
		dfs(r+1, c)
		dfs(r, c-1)
	}
	dfs(sr, sc)
	return image
}

// 695. Max Area of Island https://leetcode.com/problems/max-area-of-island/description/
func MaxAreaOfIsland(grid [][]int) int {
	res := 0
	ROWS := len(grid)
	COLS := len(grid[0])
	visited := make([][]bool, ROWS)
	for i, _ := range visited {
		visited[i] = make([]bool, COLS)
	}
	var dfs func(r, c int) int
	dfs = func(r, c int) int {
		if r == ROWS || r < 0 || c == COLS || c < 0 || grid[r][c] == 0 || visited[r][c] {
			return 0
		}
		visited[r][c] = true
		return 1 + dfs(r-1, c) + dfs(r, c+1) + dfs(r+1, c) + dfs(r, c-1)
	}
	for i := 0; i < ROWS; i++ {
		for j := 0; j < COLS; j++ {
			if !visited[i][j] && grid[i][j] == 1 {
				area := dfs(i, j)
				if area > res {
					res = area
				}
			}
		}
	}
	return res
}
