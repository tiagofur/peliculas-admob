# ProfileScreen - Quick Testing Guide

**Issue Fixed**: First click on "Mi Perfil" navigation  
**Date**: 2025-01-XX  
**Tester**: ****\_\_\_****

## Quick Test Scenarios

### ✅ TEST 1: First Navigation (CRITICAL)

**Goal**: Verify first click on "Mi Perfil" works

1. **Fresh Start**: Close and reopen the app completely
2. **Open Drawer**: Tap hamburger menu icon
3. **Click "Mi Perfil"**: First time clicking
4. **Expected**:
   - Brief loading indicator (1-2 seconds)
   - Profile screen opens successfully
   - No redirect back to home
   - No errors shown

**Result**: ☐ PASS ☐ FAIL

---

### ✅ TEST 2: Subsequent Navigation

**Goal**: Verify repeated navigation works

1. **Navigate Back**: Go back to home screen
2. **Open Drawer**: Tap hamburger menu
3. **Click "Mi Perfil"**: Second time clicking
4. **Expected**:
   - Instant navigation (no loading)
   - Profile screen opens
   - All data visible

**Result**: ☐ PASS ☐ FAIL

---

### ✅ TEST 3: Profile Edit & Save

**Goal**: Verify save functionality works

1. **Navigate to Profile**: As in TEST 1
2. **Tap Edit**: Click edit icon in app bar
3. **Make Changes**:
   - Change name: ********\_********
   - Change bio: ********\_********
4. **Tap Guardar**: Save button
5. **Expected**:
   - No error messages
   - Success confirmation
   - Data persists after reload

**Result**: ☐ PASS ☐ FAIL

---

### ✅ TEST 4: Clear Username

**Goal**: Verify username clearing works

1. **Edit Profile**: Enter edit mode
2. **Clear Username**: Delete all text in username field
3. **Save**: Tap Guardar
4. **Expected**:
   - Saves successfully
   - No "ON CONFLICT" error
   - Username cleared in profile

**Result**: ☐ PASS ☐ FAIL

---

### ✅ TEST 5: Slow Network

**Goal**: Verify loading states display correctly

1. **Enable Network Throttling**: (Developer options)
2. **Fresh App Start**: Close and reopen
3. **Navigate to Profile**: From drawer
4. **Expected**:
   - "Cargando perfil..." message shows
   - Loading spinner visible
   - Eventually loads or shows error
   - No premature redirects

**Result**: ☐ PASS ☐ FAIL

---

### ✅ TEST 6: Guest Mode

**Goal**: Verify behavior for non-authenticated users

1. **Logout**: (if logged in)
2. **Open Drawer**: Tap menu
3. **Click "Mi Perfil"**
4. **Expected**:
   - Brief loading
   - "Inicia sesión para ver tu perfil" message
   - Login and Register buttons visible
   - No crashes

**Result**: ☐ PASS ☐ FAIL

---

## Error Scenarios to Check

### ❌ Should NOT Happen:

- [ ] Immediate redirect to home on first click
- [ ] "No se pudo cargar el perfil" error (for logged-in users)
- [ ] "ON CONFLICT" database errors
- [ ] "Error al guardar cambios" when saving
- [ ] Drawer closes without navigation
- [ ] App crashes

### ✅ Should Happen:

- [x] Loading indicator shows briefly
- [x] Profile loads on first click
- [x] Save works without errors
- [x] Username can be cleared
- [x] Guest users see login prompt

---

## Performance Checks

| Action                | Expected Time | Actual Time | Status |
| --------------------- | ------------- | ----------- | ------ |
| First navigation      | < 2s          | **\_** s    | ☐      |
| Subsequent navigation | < 500ms       | **\_** ms   | ☐      |
| Save profile          | < 3s          | **\_** s    | ☐      |
| Load profile data     | < 2s          | **\_** s    | ☐      |

---

## Device Information

- **Device**: ********\_********
- **OS Version**: ********\_********
- **App Version**: ********\_********
- **Network**: Wi-Fi / Mobile Data / Offline
- **Date Tested**: ********\_********

---

## Notes

### Issues Found:

```
(List any issues discovered during testing)




```

### Observations:

```
(Any other relevant observations)




```

---

## Sign-Off

**Tester Name**: ********\_********  
**Date**: ********\_********  
**Status**: ☐ All Tests Passed ☐ Issues Found

**Approved for Production**: ☐ YES ☐ NO

---

## Quick Command Reference

```bash
# Run static analysis
flutter analyze lib/presentation/screens/profile/profile_screen.dart

# Run all tests
flutter test

# Run integration tests
flutter test integration_test/

# Check code formatting
dart format lib/presentation/screens/profile/profile_screen.dart
```

---

## Expected Logs (for Developers)

When navigating to profile, you should see:

```
[INFO] ⏳ Esperando inicialización de usuario...
[INFO] 🔄 Cargando perfil del usuario autenticado: [user_id]
[INFO] ProfileScreen.build: user=[user_id], profile=[profile_id], isLoading=false
```

**NOT this**:

```
[WARNING] ⚠️ No hay usuario autenticado ni userId en URL
[ERROR] ❌ Error al cargar datos del perfil
```
