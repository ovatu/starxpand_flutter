enum DrawerOpenedMethod {
  byHand,
  byCommand;

  static DrawerOpenedMethod fromName(String name) =>
      DrawerOpenedMethod.values.where((e) => e.name == name).first;
}

class StarPrinterStatusDetail {
  bool? cleaningNotification;
  bool? cutterError;
  int? detectedPaperWidth;
  bool? drawer1OpenCloseSignal;
  DrawerOpenedMethod? drawer1OpenedMethod;
  bool? drawer2OpenCloseSignal;
  DrawerOpenedMethod? drawer2OpenedMethod;
  bool? drawerOpenError;
  bool? externalDevice1Connected;
  bool? externalDevice2Connected;
  bool? paperJamError;
  bool? paperPresent;
  bool? paperSeparatorError;
  bool? partsReplacementNotification;
  bool? printUnitOpen;
  bool? rollPositionError;

  StarPrinterStatusDetail.fromMap(Map<String, dynamic> data)
      : cleaningNotification = data['cleaningNotification'],
        cutterError = data['cutterError'],
        detectedPaperWidth = data['detectedPaperWidth'],
        drawer1OpenCloseSignal = data['drawer1OpenCloseSignal'],
        drawer1OpenedMethod = (data['drawer1OpenedMethod'] as String?) != null
            ? DrawerOpenedMethod.fromName(data['drawer1OpenedMethod'])
            : null,
        drawer2OpenCloseSignal = data['drawer2OpenCloseSignal'],
        drawer2OpenedMethod = (data['drawer2OpenedMethod'] as String?) != null
            ? DrawerOpenedMethod.fromName(data['drawer2OpenedMethod'])
            : null,
        drawerOpenError = data['drawerOpenError'],
        externalDevice1Connected = data['externalDevice1Connected'],
        externalDevice2Connected = data['externalDevice2Connected'],
        paperJamError = data['paperJamError'],
        paperPresent = data['paperPresent'],
        paperSeparatorError = data['paperSeparatorError'],
        partsReplacementNotification = data['partsReplacementNotification'],
        printUnitOpen = data['printUnitOpen'],
        rollPositionError = data['rollPositionError'];
}

class StarXpandStatus {
  bool? hasError = false;
  bool? coverOpen = false;
  bool? drawerOpenCloseSignal = false;
  bool? paperEmpty = false;
  bool? paperNearEmpty = false;
  Map<String, dynamic>? reserved = {};
  StarPrinterStatusDetail detail;

  StarXpandStatus.fromMap(Map<String, dynamic> response)
      : hasError = response['hasError'],
        coverOpen = response['coverOpen'],
        drawerOpenCloseSignal = response['drawerOpenCloseSignal'],
        paperEmpty = response['paperEmpty'],
        paperNearEmpty = response['paperNearEmpty'],
        reserved = (response['reserved'] as Map?) != null
            ? (response['reserved'] as Map).cast<String, dynamic>()
            : {},
        detail = StarPrinterStatusDetail.fromMap(
            (response['detail'] as Map).cast<String, dynamic>());
}
