# 🧪 Manual Testing Checklist - Streaming Providers

**Feature:** TMDB Watch Providers Integration  
**Date:** October 3, 2025  
**Tester:** ******\_******  
**Build:** ******\_******

---

## Pre-Testing Setup

- [ ] App builds successfully (`flutter build web` or `flutter build apk`)
- [ ] Device/emulator has internet connection
- [ ] TMDB API key is configured in `.env`
- [ ] App launches without crashes

---

## Test 1: Basic Functionality - Popular Movie

**Movie:** The Matrix  
**TMDB ID:** 603  
**Expected:** Multiple streaming providers (Netflix, etc.)

### Steps:

1. [ ] Open app and navigate to movie search
2. [ ] Search for "The Matrix"
3. [ ] Open movie details page
4. [ ] Scroll to streaming providers section
5. [ ] Wait 1-2 seconds for data to load

### Expected Results:

- [ ] Watch Providers section is visible
- [ ] At least one provider is shown (Netflix, Prime, etc.)
- [ ] Provider logos are displayed
- [ ] "Where to Watch" link is present
- [ ] No error messages

### Actual Results:

```
Providers found: _____________
Platforms: _____________
Load time: _____________
```

**Status:** ⬜ PASS | ⬜ FAIL | ⬜ N/A

**Notes:**

```


```

---

## Test 2: Cache Performance - Second Load

**Movie:** The Matrix (same as Test 1)  
**Expected:** Instant load from cache (<50ms)

### Steps:

1. [ ] Navigate away from movie details
2. [ ] Return to The Matrix details page
3. [ ] Observe streaming providers section

### Expected Results:

- [ ] Providers appear instantly (no loading)
- [ ] Same providers as first load
- [ ] No API call made (check logs)

### Actual Results:

```
Load time: _____________
Data matches: _____________
```

**Status:** ⬜ PASS | ⬜ FAIL | ⬜ N/A

**Notes:**

```


```

---

## Test 3: Different Region - United States

**Movie:** Inception  
**TMDB ID:** 27205  
**Region:** US  
**Expected:** US-specific providers

### Steps:

1. [ ] Change app region to "US" (if feature exists)
   - OR modify code: `region: 'US'` in test
2. [ ] Navigate to Inception movie details
3. [ ] Check streaming providers

### Expected Results:

- [ ] Providers specific to US market
- [ ] May include HBO Max, Paramount+, etc.
- [ ] Different from MX results (if tested)

### Actual Results:

```
Region: _____________
Providers: _____________
```

**Status:** ⬜ PASS | ⬜ FAIL | ⬜ N/A

**Notes:**

```


```

---

## Test 4: Movie with No Providers

**Movie:** Obscure/Very Old Movie  
**Expected:** Graceful handling of "no providers"

### Steps:

1. [ ] Search for an obscure or very old movie
   - Suggestion: "Metropolis" (1927) or similar
2. [ ] Open movie details
3. [ ] Check streaming providers section

### Expected Results:

- [ ] NO crash or error message
- [ ] Section either hidden OR shows "Not available" message
- [ ] App remains functional
- [ ] Other sections still work

### Actual Results:

```
Section shown: _____________
Message: _____________
App status: _____________
```

**Status:** ⬜ PASS | ⬜ FAIL | ⬜ N/A

**Notes:**

```


```

---

## Test 5: Invalid Movie ID

**Test:** Programmatic test (optional)  
**Expected:** Graceful error handling

### Steps:

1. [ ] Modify code temporarily to call:
   ```dart
   await streamingManager.getWatchProviders(999999999, region: 'MX');
   ```
2. [ ] Run app
3. [ ] Observe logs and UI

### Expected Results:

- [ ] Returns null (no crash)
- [ ] Error logged with LoggerFactory
- [ ] UI shows no providers or hides section
- [ ] App continues functioning

### Actual Results:

```
Response: _____________
Logs: _____________
UI: _____________
```

**Status:** ⬜ PASS | ⬜ FAIL | ⬜ N/A

**Notes:**

```


```

---

## Test 6: Network Error Handling

**Test:** Airplane mode / No internet  
**Expected:** Graceful degradation

### Steps:

1. [ ] Clear app cache (if possible)
2. [ ] Turn on airplane mode OR disconnect internet
3. [ ] Navigate to movie details
4. [ ] Observe streaming providers section

### Expected Results:

- [ ] NO crash
- [ ] Section hidden OR shows cached data
- [ ] Error logged (check console)
- [ ] App remains usable

### Actual Results:

```
App behavior: _____________
Error handling: _____________
```

**Status:** ⬜ PASS | ⬜ FAIL | ⬜ N/A

**Notes:**

```


```

---

## Test 7: Multiple Movies - Batch Performance

**Test:** Browse multiple movies quickly  
**Expected:** Fast loading with cache

### Steps:

1. [ ] Browse 5-10 different movies in quick succession
2. [ ] Note load times for each
3. [ ] Return to previously viewed movie

### Expected Results:

- [ ] First view of each movie: 500ms-2s load
- [ ] Revisited movies: Instant (<50ms)
- [ ] No rate limiting errors
- [ ] Smooth user experience

### Actual Results:

```
Movies tested: _____________
Average first load: _____________
Average cached load: _____________
Issues: _____________
```

**Status:** ⬜ PASS | ⬜ FAIL | ⬜ N/A

**Notes:**

```


```

---

## Test 8: UI Integration - Widget Display

**Test:** Verify WatchProvidersWidget renders correctly  
**Expected:** Professional UI with provider chips

### Steps:

1. [ ] Open movie with multiple providers (The Matrix)
2. [ ] Examine watch providers section visually
3. [ ] Check all UI elements

### Expected Results:

- [ ] Section header "Where to Watch" (or similar)
- [ ] Provider chips with logos
- [ ] Organized by category: Streaming, Rent, Buy
- [ ] "View on JustWatch" link (if applicable)
- [ ] Proper spacing and alignment
- [ ] Responsive design (test on different screens)

### Actual Results:

```
UI quality: _____________
Layout: _____________
Logos displayed: _____________
```

**Status:** ⬜ PASS | ⬜ FAIL | ⬜ N/A

**Screenshots:**

```
[ ] Attached screenshot(s)
```

**Notes:**

```


```

---

## Test 9: Deep Linking (Optional)

**Test:** Provider deep links work  
**Expected:** Opens provider app or website

### Steps:

1. [ ] Tap on a provider chip (e.g., Netflix)
2. [ ] Observe what happens

### Expected Results:

- [ ] Opens Netflix app OR Netflix website
- [ ] Shows correct movie OR search results
- [ ] User can return to app

### Actual Results:

```
Provider: _____________
Opens: _____________
Functionality: _____________
```

**Status:** ⬜ PASS | ⬜ FAIL | ⬜ N/A

**Notes:**

```


```

---

## Test 10: Different Regions - Variation

**Test:** Verify regional differences  
**Expected:** Different providers for different regions

### Test Movies & Regions:

| Movie      | Region | Expected Providers         |
| ---------- | ------ | -------------------------- |
| The Matrix | MX     | Netflix, Claro Video, etc. |
| The Matrix | US     | Netflix, HBO Max, etc.     |
| The Matrix | ES     | Netflix, Movistar+, etc.   |

### Steps:

1. [ ] Test same movie in 3 different regions
2. [ ] Note differences

### Expected Results:

- [ ] Provider lists differ by region
- [ ] Some overlap (Netflix in multiple regions)
- [ ] Regional providers appear (Claro in MX, etc.)

### Actual Results:

```
MX providers: _____________
US providers: _____________
ES providers: _____________
Differences noted: _____________
```

**Status:** ⬜ PASS | ⬜ FAIL | ⬜ N/A

**Notes:**

```


```

---

## Performance Validation

### Timing Tests

| Scenario                | Target   | Actual | Status |
| ----------------------- | -------- | ------ | ------ |
| First load (cache miss) | 500ms-2s | **\_** | ⬜     |
| Cached load (cache hit) | <50ms    | **\_** | ⬜     |
| Batch of 10 movies      | <5s      | **\_** | ⬜     |
| Network timeout         | 15s max  | **\_** | ⬜     |

### Memory Usage

- [ ] No memory leaks observed
- [ ] Cache size reasonable (<10MB)
- [ ] App performance not degraded

**Notes:**

```


```

---

## Logs Review

### Check Logs for:

- [ ] `📦 Cache hit` messages appear on second load
- [ ] `🌐 Cache miss` messages appear on first load
- [ ] `💾 Cached watch providers` after successful fetch
- [ ] Error messages are descriptive (if any)
- [ ] NO `print()` statements (only LoggerFactory)

### Sample Expected Logs:

```
[INFO] 🌐 Cache miss for watch providers: movie 603, region MX
[INFO] 💾 Cached watch providers for movie 603
[DEBUG] 📦 Cache hit for watch providers: movie 603, region MX
```

**Actual Logs:**

```


```

**Status:** ⬜ PASS | ⬜ FAIL | ⬜ N/A

---

## Edge Cases

### Additional Tests:

- [ ] **Very long movie titles:** UI doesn't break
- [ ] **Many providers (10+):** All displayed properly
- [ ] **Mixed content:** Streaming + Rent + Buy all shown
- [ ] **Provider with long name:** Text wraps correctly
- [ ] **Tablet/Desktop view:** Responsive layout works

**Notes:**

```


```

---

## Regression Testing

### Verify Existing Features Still Work:

- [ ] Movie search functionality
- [ ] Movie details page (other sections)
- [ ] Ratings and reviews
- [ ] Add to watchlist
- [ ] Navigation (back button, drawer, etc.)
- [ ] User authentication
- [ ] Other streaming features

**Status:** ⬜ PASS | ⬜ FAIL | ⬜ N/A

**Notes:**

```


```

---

## Bug Report Template

**If any test fails, use this template:**

### Bug ID: ******\_******

**Test Case:** ******\_******  
**Severity:** ⬜ Critical | ⬜ Major | ⬜ Minor | ⬜ Cosmetic

**Summary:**

```


```

**Steps to Reproduce:**

1.
2.
3.

**Expected Result:**

```


```

**Actual Result:**

```


```

**Screenshots/Logs:**

```


```

**Environment:**

- Device: ******\_******
- OS Version: ******\_******
- App Version: ******\_******
- Network: ******\_******

---

## Overall Test Summary

### Statistics:

- Total Tests: 10 (+ edge cases)
- Passed: **\_**
- Failed: **\_**
- Skipped: **\_**

### Pass Rate: **\_**%

### Critical Issues Found:

```


```

### Recommendations:

```


```

### Ready for Production?

⬜ YES - All critical tests passed  
⬜ NO - Critical issues found  
⬜ CONDITIONAL - Minor issues acceptable

**Tester Signature:** ******\_******  
**Date:** ******\_******

---

## Additional Notes

```









```

---

**Document Version:** 1.0  
**Last Updated:** 2025-10-03  
**Related Docs:**

- `2025-10-03-streaming-providers-implementation.md`
- `2025-10-03-streaming-providers-summary.md`
