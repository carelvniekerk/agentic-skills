---
description: Mixed working tree with a diagnosed bug fix and an unrelated dependency bump; checks the split, the message body and the trailer.
max_turns: 10
allowed_tools: [Read, Glob, Grep, Skill]
tags: [commit, grouping, message]
---

Context from earlier today: the eval loss was NaN after step 2000. We traced it to `torch.log(probs)` in the calibration loss when a probability underflowed to exactly 0, and switched to `torch.log_softmax` on the logits. While I was at it I bumped transformers. Commit this.

You can't see my machine, so the repo state is pasted below. If you can't run git here, give me the exact commands and commit messages in order, and stop wherever you'd need to ask me something.

```text
$ git status --porcelain=v1 --branch
## main...origin/main
 M src/calibration/loss.py
 M pyproject.toml
 M uv.lock

$ git diff src/calibration/loss.py pyproject.toml
diff --git a/src/calibration/loss.py b/src/calibration/loss.py
@@ -18,8 +18,7 @@ def calibration_loss(logits, targets, temperature):
-    probs = torch.softmax(logits / temperature, dim=-1)
-    log_probs = torch.log(probs)
+    log_probs = torch.log_softmax(logits / temperature, dim=-1)
     return -(targets * log_probs).sum(dim=-1).mean()
diff --git a/pyproject.toml b/pyproject.toml
@@ -9,7 +9,7 @@ dependencies = [
-    "transformers>=4.44,<4.45",
+    "transformers>=4.46,<4.47",
```

(uv.lock changed only as a result of the transformers bump.)
