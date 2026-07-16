🧠 Pattern: Interval Management (Sorting and Merging)

The Intuition: Sequential Processing

Interval problems often involve optimizing resource allocation, scheduling, or geometric overlaps. The moment you see ranges ([start, end]), your mind should immediately go to Sorting.

Why? Sorting by the start time ensures that when you process interval $A$, any interval $B$ that could possibly affect it (by starting earlier) has already been processed.

🔍 How to Recognize This Pattern
|Signal|Problem Type|
|---|---|
|Input: Arrays of [start, end] pairs.|This is the primary signal.|
|Goal: "Merge," "Find Overlap," "Check Conflicts."|Indicates a need for sequential comparison.|
|Key Check: Comparing End of the previous interval with Start of the current one.|The core decision logic.|

🧠 Pattern: Prefix/Suffix Array (Two-Pass Accumulation)The Intuition: Divide and Conquer with HistoryWhen you need to compute a value at index $i$ that depends on data both before $i$ and after $i$, and you are restricted to $O(N)$ time (ruling out nested loops) and $O(1)$ extra space (ruling out two large helper arrays), you use this two-pass accumulation method.The "Aha!" MomentThe key insight is realizing you can break the calculation into two independent, sequential problems:Left-to-Right Pass (Prefix): Calculate and store all the "left history" in the result array.Analogy: You are a tourist walking East, recording the total distance traveled so far at every city sign.Right-to-Left Pass (Suffix): Calculate the "right history" on the fly using a single variable (rightProduct), and combine it with the "left history" (which is already stored in the result array).Analogy: You are now walking West. At each city, you grab the total distance recorded from the East journey (the prefix) and multiply it by the distance you've traveled West so far (the suffix), then update your West distance for the next step.🔍 Recognition SignalsSignalPattern"Calculate value at $i$ based on neighbors."The core requirement for prefix/suffix."Solve in $O(N)$ without division."This specific constraint almost always forces the two-pass Prefix/Suffix strategy."Need to avoid nested loops"Accumulating data across passes is the $O(N)$ solution for complex array queries.