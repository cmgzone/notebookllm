# Planning Mode - Requirements Addition Fix

## Problem
Users were unable to manually add requirements in Planning Mode, and AI-generated requirements were not rendering in the Requirements tab.

## Root Causes

### Issue 1: No Manual UI for Adding Requirements
The `plan_detail_screen.dart` UI had a Requirements tab that displayed requirements, but there was no button or UI element to manually add new requirements. The functionality existed in the backend and provider layers, but was not exposed in the UI.

### Issue 2: Backend Default Parameter Bug
The backend `planService.getPlan()` method had `includeRelations: boolean = false` as the default, which meant requirements and design notes were NOT being loaded by default. This caused AI-generated requirements to be saved successfully but not appear in the UI after the plan was reloaded.

## Solution

### Fix 1: Added Manual Creation UI
Added manual requirement and design note creation dialogs with floating action buttons (FABs) in the respective tabs.

#### Requirements Section Enhancement
**File:** `lib/features/planning/ui/plan_detail_screen.dart`

- Converted `_RequirementsSection` from `StatelessWidget` to `ConsumerWidget` to access the provider
- Added a floating action button (+) in the requirements tab
- Created `_showAddRequirementDialog()` method with a comprehensive form including:
  - **Title field** (required)
  - **Description field** (optional)
  - **EARS Pattern dropdown** with all 6 pattern types:
    - Ubiquitous: THE <system> SHALL <response>
    - Event: WHEN <trigger>, THE <system> SHALL...
    - State: WHILE <condition>, THE <system> SHALL...
    - Unwanted: IF <condition>, THEN THE <system> SHALL...
    - Optional: WHERE <option>, THE <system> SHALL...
    - Complex: Combination of patterns
  - **Acceptance Criteria list** with add/remove functionality
- Updated empty state message to indicate users can tap + to add requirements

#### Design Notes Section Enhancement
**File:** `lib/features/planning/ui/plan_detail_screen.dart`

- Converted `_DesignNotesSection` from `StatelessWidget` to `ConsumerWidget`
- Added a floating action button (+) in the design notes tab
- Created `_showAddDesignNoteDialog()` method with:
  - **Content field** (required, multi-line)
  - **Link to Requirements** (optional checkboxes for existing requirements)
- Updated empty state message to indicate users can tap + to add design notes

#### Fixed Deprecation Warning
- Changed `DropdownButtonFormField.value` to `initialValue` to comply with Flutter 3.33+ API changes

### Fix 2: Backend Default Parameter
**File:** `backend/src/services/planService.ts`

Changed the default value of `includeRelations` parameter from `false` to `true` in the `getPlan()` method:

```typescript
// BEFORE (Bug)
async getPlan(
  planId: string, 
  userId: string, 
  includeRelations: boolean = false  // ❌ Wrong default
): Promise<Plan | null>

// AFTER (Fixed)
async getPlan(
  planId: string, 
  userId: string, 
  includeRelations: boolean = true  // ✅ Correct default
): Promise<Plan | null>
```

This ensures that when the plan is reloaded after adding requirements via AI or manually, the requirements are actually included in the response.

## Technical Details

### API Integration
Both dialogs use the existing provider methods:
- `planningProvider.notifier.createRequirement()`
- `planningProvider.notifier.createDesignNote()`

These methods call the backend API endpoints:
- `POST /planning/:id/requirements`
- `POST /planning/:id/design-notes`

### Data Flow
1. User adds requirement (via AI or manual dialog)
2. Frontend calls `createRequirement()` with `reloadPlan: true`
3. Backend creates requirement in database
4. Frontend calls `loadPlan()` to refresh
5. Backend `getPlan()` now defaults to `includeRelations: true`
6. Requirements are loaded and returned
7. UI updates with new requirements visible

### User Experience Improvements
1. **Intuitive UI**: FAB buttons appear in each tab where they're needed
2. **Validation**: Title/content fields are validated before submission
3. **Feedback**: Success snackbars confirm when items are added
4. **EARS Pattern Guidance**: Dropdown shows the pattern template for each option
5. **Acceptance Criteria Management**: Easy add/remove interface for criteria
6. **Requirement Linking**: Design notes can be linked to specific requirements via checkboxes

## Testing Recommendations

1. **Manual Requirement Creation**:
   - Navigate to a plan's Requirements tab
   - Click the + FAB
   - Fill in title, description, select EARS pattern
   - Add acceptance criteria
   - Verify requirement appears in the list

2. **AI-Generated Requirements**:
   - Use Planning AI to generate requirements
   - Click "Add Requirements" button
   - Navigate back to plan detail
   - Verify requirements now appear in Requirements tab

3. **Manual Design Note Creation**:
   - Navigate to a plan's Design tab
   - Click the + FAB
   - Enter design note content
   - Link to existing requirements (if any)
   - Verify design note appears in the list

4. **Validation**:
   - Try submitting empty forms
   - Verify error messages appear

5. **Mixed Workflow**:
   - Add some requirements via AI
   - Add some requirements manually
   - Verify all appear correctly

## Benefits

✅ **User Control**: Users can now manually add requirements without relying on AI
✅ **Flexibility**: Both AI-assisted and manual workflows are supported
✅ **EARS Compliance**: Built-in EARS pattern selection ensures proper requirement structure
✅ **Traceability**: Design notes can be explicitly linked to requirements
✅ **Consistency**: UI follows the same pattern as task creation (FAB + dialog)
✅ **Bug Fixed**: AI-generated requirements now render properly after being added

## Files Modified

- `lib/features/planning/ui/plan_detail_screen.dart` - Added requirement and design note creation dialogs
- `backend/src/services/planService.ts` - Fixed default parameter for `includeRelations`

## Related Features

- Planning Mode (Spec-driven development)
- EARS Pattern Requirements
- AI-assisted requirement generation
- Design documentation

