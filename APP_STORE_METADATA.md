# App Store Metadata for Pungent Roots

This document provides the required metadata for App Store Connect submission.

## App Information

### Basic Details
- **App Name**: Pungent Roots
- **Bundle ID**: co.ouchieco.PungentRoots
- **SKU**: pungent-roots-001 (or your chosen SKU)
- **Version**: 1.0
- **Build Number**: 1
- **Category**: Food & Drink
- **Content Rating**: 4+ (All Ages)

### Platform Support
- **Primary Platform**: iOS
- **Minimum iOS Version**: 16.0
- **Supported Devices**: iPhone, iPad
- **Orientations**: Portrait, Landscape

## App Description

### Short Description (30 characters max)
"Scan labels for allium ingredients"

### Promotional Text (170 characters max)
"Quickly identify onions, garlic, and other allium ingredients in food products. Perfect for people with sensitivities or dietary restrictions."

### Full Description

**Pungent Roots** helps you identify allium-containing ingredients in food products by scanning ingredient labels with your iPhone or iPad camera.

**Key Features:**
• Real-time ingredient label scanning
• Instant detection of alliums (onions, garlic, leeks, shallots, chives, and more)
• On-device processing - no internet required
• Complete privacy - no data collected or transmitted
• Fast and accurate text recognition
• Simple, accessible interface
• VoiceOver support for accessibility

**Perfect for:**
• People with allium sensitivities or intolerances
• Those following specific dietary restrictions
• Anyone avoiding onions, garlic, or related ingredients
• Quick grocery shopping decisions

**How It Works:**
1. Point your camera at an ingredient label
2. The app automatically detects and highlights allium-related terms
3. Get instant feedback on whether the product contains alliums

**Privacy First:**
All processing happens entirely on your device. We don't collect, store, or transmit any personal information, photos, or usage data. No account required.

**Technical Details:**
• Uses Apple's Vision framework for text recognition
• Comprehensive allium detection dictionary
• Supports multiple languages and ingredient variations
• Works offline - no internet connection needed

**Open Source:**
Pungent Roots is open source software, ensuring complete transparency. View the code at: https://github.com/patrickdeanbrown/PungentRoots

**Medical Disclaimer:**
This app is for informational purposes only and should not replace professional medical advice. Always verify ingredients independently for severe allergies.

## Keywords

allium, onion, garlic, ingredient scanner, food scanner, allergy, intolerance, dietary restrictions, label reader, OCR, food sensitivity, leek, shallot, chives, FODMAP, ingredient checker

## Support Information

- **Support URL**: https://github.com/patrickdeanbrown/PungentRoots
- **Marketing URL**: https://github.com/patrickdeanbrown/PungentRoots
- **Privacy Policy URL**: [Host PRIVACY_POLICY.md and provide URL]

## App Review Information

### Demo Account
Not required - no account system

### Notes for Reviewer
- Camera permission is required for core functionality (scanning labels)
- All processing is on-device; no backend server
- Test with any product ingredient label
- The app detects terms related to alliums (onions, garlic, etc.) in ingredient lists
- VisionKit's DataScannerViewController is used on supported devices (iOS 16+); legacy AVCaptureSession is fallback
- No network requests are made

### Contact Information
- **First Name**: [Your First Name]
- **Last Name**: [Your Last Name]
- **Phone Number**: [Your Phone Number]
- **Email**: [Your Email]

## App Store Questions

### Does this app use the Advertising Identifier (IDFA)?
**No**

### Does this app contain, display, or access third-party content?
**No**

### Does your app use encryption?
**No** (or if using HTTPS: "Yes, but qualifies for exemption")

### Content Rights
**I have the necessary rights to use this app and all its content**

## Privacy Labels (App Store Connect)

### Data Not Collected
- No data collection

### Data Linked to User
- None

### Data Used to Track User
- None

## App Privacy Questions

1. **Do you or your third-party partners collect data from this app?**
   - No

2. **Does your app use the camera?**
   - Yes, for scanning ingredient labels

3. **Does your app collect photos or videos?**
   - No (camera is used for real-time scanning only; no storage)

4. **Does your app use on-device processing?**
   - Yes (all OCR and detection happens locally)

## Screenshots Requirements

You need to provide screenshots for:
- 6.7" iPhone (iPhone 15 Pro Max, 14 Pro Max, 13 Pro Max, 12 Pro Max)
- 6.5" iPhone (iPhone 11 Pro Max, XS Max)
- 5.5" iPhone (iPhone 8 Plus, 7 Plus, 6s Plus)
- 12.9" iPad Pro (3rd, 4th, 5th, 6th gen)
- iPad Pro (12.9-inch) (6th generation)

Minimum: 3-10 screenshots per device size

### Screenshot Ideas
1. Main camera scanning view with ingredient label
2. Detection result showing "Alliums Detected" with highlighted terms
3. Detection result showing "Safe - No Alliums Detected"
4. Settings screen
5. App features overview
6. Privacy emphasis screen

## App Preview Video (Optional)
- 15-30 seconds recommended
- Show: Opening app → Scanning label → Results displayed
- Emphasize: Speed, accuracy, privacy

## Age Rating

### Content Rating: 4+
- No objectionable content
- No unrestricted web access
- No user-generated content
- No location services
- No advertising
- No in-app purchases

## Pricing

- **Free** (recommended for initial launch)
- Consider freemium model later if desired

## Availability

- All territories (recommended)
- Consider language support for international markets

## Version Release

- **Manual Release**: Recommended to control launch timing
- OR **Automatic Release**: Upon approval

## Additional Information

### What's New in This Version (for updates)
"Initial release of Pungent Roots - scan ingredient labels to detect alliums (onions, garlic, and related ingredients) with complete privacy."

## Localizations

Currently supports:
- English (US)

Future considerations:
- Spanish
- French
- German
- Other languages based on user demand

## Testing Checklist

Before submission:
- [ ] Test on physical iPhone device (not just simulator)
- [ ] Test on physical iPad device
- [ ] Verify camera permission prompt displays correctly
- [ ] Test with various ingredient labels
- [ ] Verify VoiceOver functionality
- [ ] Test in both light and dark mode
- [ ] Verify all orientations work correctly
- [ ] Check for crashes or performance issues
- [ ] Ensure privacy manifest is correct
- [ ] Verify build version and marketing version are correct
- [ ] Test on iOS 16.0 device (minimum supported version)

## Post-Launch

After approval:
- Monitor crash reports
- Gather user feedback
- Plan updates based on user needs
- Consider adding more languages
- Expand allium dictionary if needed
