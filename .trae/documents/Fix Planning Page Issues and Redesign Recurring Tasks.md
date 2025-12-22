I have analyzed the codebase and identified the causes for the reported issues. Here is the plan to fix them:

## 1. Fix Recurring Task Status Updates
**Problem:** The status updates for recurring tasks might not be reflecting immediately due to how the UI listens for changes in the completion history.
**Solution:**
- Verify and ensure the `TasksNotifier` correctly notifies listeners when `updateStatus` is called for a specific date.
- In the new Recurring Tasks UI, strictly pass the correct "virtual date" (the selected date) to the `updateStatus` method to ensure the completion is recorded for the correct day.

## 2. Fix New Categories Display
**Problem:** The `PlanningScreen` uses a default static list of categories (`defaultCategories`) and does not check the user-created categories stored in the database.
**Solution:**
- Update `PlanningScreen` to watch the `categoryProvider`.
- Pass the dynamic list of categories to the `getCategoryById` helper function so it can find the new categories (name, emoji, color).

## 3. Redesign Recurring Tasks Display
**Problem:** The user wants recurring tasks to be shown only once at the top, with a distinct style, larger selectable circles, and 5-state switching.
**Solution:**
- **Remove** recurring tasks from the daily/weekly lists (the "Grouped Tasks" section).
- **Create** a new `RecurringTasksHeader` widget at the very top of the Planning page (below the tab bar/date picker area, or pinned at the top of the content).
- **Style:**
    - Use a separate box with a distinct design.
    - Display tasks for the **Selected Date**.
    - **Row Item:**
        - Task Title.
        - **Large Selectable Circle:** A larger icon that indicates the current status.
        - **Interaction:** Clicking the circle will cycle through the 5 statuses (Pending -> Success -> Failed -> Deferred -> Cancelled -> Pending).
        - Maintain the overall design language (colors, fonts) but with larger touch targets for the status.

### Implementation Steps
1.  **Modify `lib/screens/planning_screen.dart`**:
    -   Inject `categoryProvider` to fix category display.
    -   Extract recurring tasks logic into a new `_buildRecurringTasksHeader` method.
    -   Remove recurring tasks from `_buildGroupedTasksContent`.
    -   Implement the new UI for the header with large status toggles.
2.  **Verify**:
    -   Check that new categories appear correctly.
    -   Check that clicking the large circle updates the status for that specific day and persists.
