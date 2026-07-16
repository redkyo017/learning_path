# 🏁 Wrap-up: Week 6 | Day 4
### Thought & Mindset
Today was about Persistence. Standard Binary Search is "greedy"—it stops as soon as it's satisfied. Boundary Binary Search is "thorough"—it records a potential answer but keeps looking to see if it can find a "better" (more extreme) one. This mindset is vital for problems where the search space has a "transition point" rather than a single target value.

### The Pattern: The Candidate Variable
1. When you aren't looking for an exact match, but rather the first or last instance of a property:
2. Initialize a res or ans variable to a default (like -1 or n).
3. When the condition is met (nums[mid] == target or isBadVersion), update the res and move towards the side you are interested in.
4. The loop will naturally terminate at the boundary, and your res will hold the last valid candidate found.  