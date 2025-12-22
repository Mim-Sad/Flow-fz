I have analyzed the requests and the codebase. Here is the implementation plan:

## 1. Add 3-Dots Menu to Planning Screen Tasks
- **File:** `lib/screens/planning_screen.dart`
- **Action:**
    - Modify `_buildCompactTaskRow` to include a 3-dots icon button at the end (similar to `HomeScreen`).
    - Bind the button to `_showTaskOptions`.
    - Update `_showTaskOptions` to handle the `PlanningScreen` context.

## 2. Implement Hold-to-Reorder (Drag & Drop)
- **Home Screen (Manual View):**
    - **Current State:** Already uses `SliverReorderableList`.
    - **Action:** Ensure `SortMode.manual` is enabled and the list is reorderable. The code seems to already support this (`isReorderEnabled: _sortMode == SortMode.manual`). I will verify and ensure the "hold" gesture works as expected. The user specifically asked for "hold to hold and move", which is standard behavior for `ReorderableListView`.
- **Planning Screen:**
    - **Challenge:** Tasks are grouped by category/time. Reordering across groups is complex.
    - **Strategy:** I will enable reordering *within* the groups (categories).
    - **Action:**
        - Wrap the list of tasks in `_buildTaskGroup` with a `ReorderableListView` (or `ReorderableColumn` if available/custom).
        - Since `ReorderableListView` requires a scrollable context, and we are inside a `ListView` (for the whole page), nesting them is tricky.
        - **Alternative:** Use `ReorderableListView` for the *entire* list of tasks if we were not grouping them. But we are.
        - **Refined Strategy for Planning Screen:** Given the constraints of the grouped UI, I will implement a visual reordering only within the category groups using a `ReorderableListView` with `shrinkWrap: true` and `physics: NeverScrollableScrollPhysics` inside each group card. This allows reordering tasks within the same category.

## 3. Change Default Sort Order in Home Screen
- **File:** `lib/screens/home_screen.dart`
- **Action:**
    - Modify the `else` block in the sorting logic (lines 40-53).
    - Implement the new priority order:
        1.  **Pending** (`TaskStatus.pending`) - "In Progress"
        2.  **Success** (`TaskStatus.success`) - "Done"
        3.  **Deferred** (`TaskStatus.deferred`)
        4.  **Failed** (`TaskStatus.failed`)
        5.  **Cancelled** (`TaskStatus.cancelled`)
    - Within same status, sort by Priority (High > Medium > Low).

## 4. Use `persian_datetime_picker` Everywhere
- **Files:** `lib/screens/home_screen.dart`, `lib/screens/add_task_screen.dart`
- **Action:**
    - In `home_screen.dart`:
        - Update swipe-to-defer logic to use `showTimePicker` after date selection (as analyzed).
        - Update status picker "Defer" option to use `showTimePicker`.
    - In `add_task_screen.dart`:
        - Ensure `showPersianDatePicker` is used (it already is).
        - Ensure `showTimePicker` is used for time selection (it already is).
    - **Verification:** I've confirmed `showPersianDatePicker` is already the primary date picker. I will just add the missing time selection for defer actions in `HomeScreen`.

## Execution Steps
1.  **Modify `lib/screens/home_screen.dart`**:
    - Update sorting logic.
    - Update defer logic (swipe & menu) to include time picking.
2.  **Modify `lib/screens/planning_screen.dart`**:
    - Add 3-dots icon to task rows.
    - Implement reordering within task groups (using `ReorderableListView`).

Let's proceed.