/// Range clamping, used by the settings setters to enforce their own limits.
extension Comparable {
    /// Constrains a value to `range`.
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
