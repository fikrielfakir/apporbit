abstract final class ApiEndPoints{
  static String baseUrl = 'https://mistyrose-coyote-824514.hostingersite.com';
  static String apiUrl = '/connector/api';

  // Stock Transfer Endpoints
  static String get stockTransfers => '$baseUrl$apiUrl/stock-transfers';
  static String getStockTransfer(String id) => '$stockTransfers/$id';
  static String updateStockTransfer(String id) => '$stockTransfers/$id';
  static String deleteContact(int id) => '$baseUrl$apiUrl/contactapi/$id';

  // Updated status endpoint to match your API
  static String updateStockTransferStatus(String id) => '$stockTransfers/$id/status';

  static String printStockTransferInvoice(String id) => '$stockTransfers/$id/print';

  ///auth
  static String loginUrl ='$baseUrl/oauth/token';
  static String getUser = '$baseUrl$apiUrl/user/loggedin';
  // Add these endpoints
  static String updatePasswordUrl = "$baseUrl$apiUrl/update-password";
  static String forgotPasswordUrl = "$baseUrl$apiUrl/forget-password";

  ///attendance
  static String checkIn ='$baseUrl$apiUrl/clock-in';
  static String checkOut ='$baseUrl$apiUrl/clock-out';
  static String getAttendance ='$baseUrl$apiUrl/get-attendance/';

  ///contact
  static String contact = '$baseUrl$apiUrl/contactapi';
  static String getContact = '$contact?type=customer&per_page=500';
  static String addContact = '$contact?type=customer';
  static String updateContact = '$contact'; // Add this line
  static String deleteStockTransfer(String id) => '$contact/$id'; // Add this line for delete
  
  //contact payment
  static String customerDue = '$contact/';
  static String addContactPayment = '$contact-payment';

  //#endregion

  //#region used by Dio

  ///Notifications
  static String allNotifications = '$apiUrl/notifications';

  ///brands
  static String allBrands = '$apiUrl/brand';

  ///Purchases
  static String purchases = '$apiUrl/purchases';
//#endregion
}