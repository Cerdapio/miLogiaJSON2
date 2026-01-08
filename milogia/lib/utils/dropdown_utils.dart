
// Helper function to ensure the dropdown value is valid.
// Returns the current value if it exists in the list, otherwise returns the first item or null.
T? ensureValidDropdownValue<T>(T? currentValue, List<T> items) {
  if (items.isEmpty) return null;
  if (currentValue != null && items.contains(currentValue)) {
    return currentValue;
  }
  // If currentValue is invalid or null, default to the first item (or null if preferred, but usually we want a selection)
  // However, for nullable dropdowns, null is valid. But if the UI expects a non-null selection eventually:
  return items.first; 
}
