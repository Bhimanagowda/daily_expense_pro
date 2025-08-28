// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Daily Expense Pro';

  @override
  String get home => 'Home';

  @override
  String get details => 'Details';

  @override
  String get charts => 'Charts';

  @override
  String get borrow => 'Borrow';

  @override
  String get lend => 'Lend';

  @override
  String get profile => 'Profile';

  @override
  String get notes => 'Notes';

  @override
  String get settings => 'Settings';

  @override
  String get addNewExpense => 'Add New Expense';

  @override
  String get scanReceipt => 'Scan Receipt';

  @override
  String get totalExpense => 'Total Expense';

  @override
  String get category => 'Category';

  @override
  String get itemName => 'Item Name';

  @override
  String get itemPrice => 'Item Price';

  @override
  String get paymentMethod => 'Payment Method';

  @override
  String get cancel => 'Cancel';

  @override
  String get add => 'Add';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get restaurants => 'Restaurants';

  @override
  String get transport => 'Transport';

  @override
  String get groceries => 'Groceries';

  @override
  String get vegetablesFruits => 'Vegetables & Fruits';

  @override
  String get personalCare => 'Personal Care';

  @override
  String get homeUtilities => 'Home & Utilities';

  @override
  String get clothingAccessories => 'Clothing & Accessories';

  @override
  String get entertainment => 'Entertainment';

  @override
  String get others => 'Others';

  @override
  String get cash => 'Cash';

  @override
  String get online => 'Online';

  @override
  String get selectCategory => 'Select Category';

  @override
  String get selectPaymentMethod => 'Select Payment Method';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get kannada => 'ಕನ್ನಡ';

  @override
  String get changeLanguage => 'Change Language';

  @override
  String get pleaseSelectCategory => 'Please select a category';

  @override
  String get pleaseEnterItemName => 'Please enter item name';

  @override
  String get pleaseEnterValidPrice => 'Please enter a valid price';

  @override
  String get pleaseSelectPaymentMethod => 'Please select payment method';

  @override
  String get expenseAdded => 'Expense added successfully!';

  @override
  String get expenseUpdated => 'Expense updated successfully!';

  @override
  String get expenseDeleted => 'Expense deleted successfully!';

  @override
  String get confirmDelete => 'Are you sure you want to delete this item?';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get logout => 'Logout';

  @override
  String get totalAmount => 'Total Amount';

  @override
  String get items => 'Items';

  @override
  String get downloadWithDateRange => 'Download with Date Range';

  @override
  String get noItemsAdded => 'No items added.';

  @override
  String get deleteSelected => 'Delete Selected';

  @override
  String get updateItem => 'Update Item';

  @override
  String get update => 'Update';

  @override
  String get analysis => 'Analysis';

  @override
  String get dailyExpenditure => 'Daily Expenditure';

  @override
  String get enterFileName => 'Enter file name';

  @override
  String get fileNameHint => 'File name (without .xlsx)';

  @override
  String get ok => 'OK';

  @override
  String get selectDateRange => 'Select Date Range';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get last7Days => 'Last 7 days';

  @override
  String get last30Days => 'Last 30 days';

  @override
  String get thisMonth => 'This month';

  @override
  String get lastMonth => 'Last month';

  @override
  String get customRange => 'Custom range';

  @override
  String get fromDate => 'From date';

  @override
  String get toDate => 'To date';

  @override
  String get selectStartDate => 'Select start date';

  @override
  String get selectEndDate => 'Select end date';

  @override
  String get pleaseSelectBothDates => 'Please select both start and end dates';

  @override
  String excelFileDownloaded(Object filePath) {
    return 'Excel file downloaded to $filePath';
  }

  @override
  String get datetime => 'DATETIME';
}
