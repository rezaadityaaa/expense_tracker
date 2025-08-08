# Expense Tracker App Icon

## Icon Design Specifications

### Main App Icon (1024x1024)
- Background: Blue gradient (#0288D1 to #29B6F6)
- Icon: White wallet/money symbol
- Style: Modern, flat design with subtle shadow
- Shape: Rounded square (iOS) / Adaptive (Android)

### Colors Used:
- Primary Blue: #0288D1
- Light Blue: #29B6F6
- Dark Blue: #0277BD
- White: #FFFFFF
- Shadow: rgba(0,0,0,0.2)

### File Structure:
```
assets/icons/
├── app_icon.png (1024x1024) - Main app icon
├── app_icon_foreground.png (1024x1024) - Foreground for adaptive icon
└── app_icon_background.png (1024x1024) - Background for adaptive icon
```

## Design Description:
The app icon features a modern wallet symbol on a beautiful blue gradient background. 
The design is clean, professional, and instantly recognizable as a financial/expense tracking application.

### Icon Elements:
1. **Background**: Smooth gradient from light blue to darker blue
2. **Main Symbol**: Stylized wallet with money/cards visible
3. **Typography**: Clean, modern sans-serif (if text is used)
4. **Shadow**: Subtle drop shadow for depth

## Instructions for Creating Actual Icons:
1. Use a design tool like Figma, Adobe Illustrator, or Canva
2. Create a 1024x1024 canvas
3. Apply the blue gradient background
4. Add the wallet icon in white
5. Export as PNG with transparency where needed
6. Use flutter_launcher_icons to generate all required sizes

## Alternative: Use Material Icons
For development purposes, you can use Material Icons until custom icons are created:
- account_balance_wallet_rounded
- wallet
- payments
- account_balance

## Generate Icons Command:
After adding your custom PNG files, run:
```
flutter pub get
flutter pub run flutter_launcher_icons:main
```
