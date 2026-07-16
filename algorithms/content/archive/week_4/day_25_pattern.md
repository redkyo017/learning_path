# 🏁 Day 3 Wrap-up: String Parsing & Hierarchy

## 🧠 Mindset: "Stacks as Memory"
Day 3 was about using the Stack to handle incomplete information.
- In Simplify Path, we didn't know if a directory was "final" until we saw if the next token was ...
- In RPN, we didn't know what to do with a number until we saw an operator.

The Stack acts as a waiting room for data that is "pending" an action.

### 🛠️ Patterns Mastered
|Pattern|Insight|Applied To|
---|---|---
Path Simplification|Use a stack to track "depth." Pushing enters a folder, popping exits to the parent.|71. Simplify Path|
Postfix Evaluation|Operators act on the two most recent items in the stack. Order matters for / and -.|150. Evaluate RPN