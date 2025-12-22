I have analyzed the request and the existing codebase. The user wants to:

1.  **Redesign Recurring Tasks in `PlanningScreen`**:
    -   **Style**: Match the "Category Card" design (likely `_buildTaskGroup`).
    -   **Content**: Show 7 days (circles) instead of 1 checkbox. Circles should be present even if the task isn't scheduled for that day (faded/greyed out).
    -   **Position**: Not sticky, just placed at the top (already done, but needs refinement).
    -   **Daily View**: Show as a normal task (already done).
    -   **Weekly/Monthly View**: Show the new "7-day" design.
    -   **Interactions**:
        -   **Hold**: Drag & drop only (disable settings sheet on hold).
        -   **Tap on Circle**: Change status (opens status sheet? No, user said "Hold on task circle opens status sheet" in general, but for recurring they said "Tap on circle switch 5 states" in previous prompt. I will clarify or stick to the previous pattern: Tap to toggle/cycle, Hold to show status sheet?
        -   *Correction based on new prompt*: "Hold on task circle opens status sheet" and "Tap on 3-dots opens settings sheet". "Hold on task body" is for drag/drop.
        -   **Wait**, the prompt says: "Hold on task circle opens status sheet" (for normal tasks presumably?) AND "Hold on task body is for move".
        -   For recurring tasks specifically: "Instead of 1 checkbox have 7... if a day is missing show faded circle".

2.  **Unify Status Picker Sheet**:
    -   Create a shared widget `TaskStatusPickerSheet`.
    -   Design: Compact row, colored icons.
    -   Apply to `HomeScreen` and `PlanningScreen`.

3.  **Unify Task Options Sheet**:
    -   Create a shared widget `TaskOptionsSheet`.
    -   Apply to `HomeScreen` and `PlanningScreen`.

### Plan

1.  **Create Shared Widgets**:
    -   `lib/widgets/task_sheets.dart`: Will contain `TaskOptionsSheet` and `TaskStatusPickerSheet`.
    -   **Logic**: `TaskStatusPickerSheet` needs to handle the `showPersianDatePicker` logic for deferred tasks, which is currently duplicated.

2.  **Refactor `HomeScreen`**:
    -   Replace inline `_showTaskOptions` and `_showStatusPicker` with the new widgets.
    -   Update `TaskListTile` to support the new interaction model (Hold body -> Drag, Hold circle -> Status Sheet).

3.  **Refactor `PlanningScreen`**:
    -   Replace inline sheets with new widgets.
    -   **Redesign Recurring Tasks**:
        -   Create a new widget `RecurringTaskCard` (or similar) that looks like `_buildTaskGroup`.
        -   Implement the 7-day circle row logic.
        -   Ensure it only appears in Weekly/Monthly views? The prompt says "In daily view show like normal task... in weekly/monthly show the design I say".
        -   So, in `_buildDailyView`, we render them as standard `TaskListTile`.
        -   In `_buildRecurringTasksHeader` (which is visible in all views currently), we need to adapt. Wait, `_buildRecurringTasksHeader` was added to be "at the top".
        -   *Correction*: The user says "In daily view show like normal task". This implies they might want the "Header" to disappear in Daily view and merge into the list? OR the header changes style.
        -   Actually, `_buildRecurringTasksHeader` is *outside* the view mode logic.
        -   I will modify `_buildRecurringTasksHeader` to **only** render the "7-day card style" when **NOT** in Daily view? Or render it always but change style?
        -   Let's look at the prompt: "In daily view show like normal task with a circle, in weekly/monthly design that I say".
        -   Okay, so in Daily View, recurring tasks should probably just be mixed in with the list (or in a header that looks like a normal task list).
        -   I will assume:
            -   **Daily View**: Recurring tasks are part of the normal list (or a simple header looking like a list).
            -   **Weekly/Monthly**: Use the new "Category-like" card with 7 circles.

4.  **Refactor `TaskCard`**:
    -   Update to use the shared sheets.

### Implementation Details
-   **Status Sheet**: Row of icons. `InkWell` on each.
-   **Options Sheet**: List of tiles (Edit, Change Status, Delete).
-   **Recurring Card**:
    -   Container with border/radius (like categories).
    -   Row: Title + Emoji + Priority.
    -   Row below: 7 circles (Mon-Fri...).
    -   Status logic for specific dates.

Let's start by creating the shared widgets.
