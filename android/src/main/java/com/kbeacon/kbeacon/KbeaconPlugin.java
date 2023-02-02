package com.kbeacon.kbeacon;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.content.Context;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.os.Build;
import android.util.Log;
import android.view.View;
import android.widget.EditText;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import com.kkmcn.kbeaconlib2.KBAdvPackage.KBAccSensorValue;
import com.kkmcn.kbeaconlib2.KBAdvPackage.KBAdvPacketBase;
import com.kkmcn.kbeaconlib2.KBAdvPackage.KBAdvPacketEddyTLM;
import com.kkmcn.kbeaconlib2.KBAdvPackage.KBAdvPacketEddyUID;
import com.kkmcn.kbeaconlib2.KBAdvPackage.KBAdvPacketEddyURL;
import com.kkmcn.kbeaconlib2.KBAdvPackage.KBAdvPacketIBeacon;
import com.kkmcn.kbeaconlib2.KBAdvPackage.KBAdvPacketSensor;
import com.kkmcn.kbeaconlib2.KBAdvPackage.KBAdvPacketSystem;
import com.kkmcn.kbeaconlib2.KBAdvPackage.KBAdvType;
import com.kkmcn.kbeaconlib2.KBCfgPackage.KBAdvMode;
import com.kkmcn.kbeaconlib2.KBCfgPackage.KBAdvTxPower;
import com.kkmcn.kbeaconlib2.KBCfgPackage.KBCfgAdvIBeacon;
import com.kkmcn.kbeaconlib2.KBCfgPackage.KBCfgBase;
import com.kkmcn.kbeaconlib2.KBCfgPackage.KBCfgCommon;
import com.kkmcn.kbeaconlib2.KBCfgPackage.KBCfgTrigger;
import com.kkmcn.kbeaconlib2.KBCfgPackage.KBTriggerAction;
import com.kkmcn.kbeaconlib2.KBCfgPackage.KBTriggerType;
import com.kkmcn.kbeaconlib2.KBConnState;
import com.kkmcn.kbeaconlib2.KBConnectionEvent;
import com.kkmcn.kbeaconlib2.KBException;
import com.kkmcn.kbeaconlib2.KBeacon;
import com.kkmcn.kbeaconlib2.KBeaconsMgr;

import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Locale;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/** KbeaconPlugin */
public class KbeaconPlugin implements FlutterPlugin, MethodCallHandler, ActivityAware,
        KBeaconsMgr.KBeaconMgrDelegate, EventChannel.StreamHandler, KBeacon.ConnStateDelegate,  KBeacon.NotifyDataDelegate{
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private MethodChannel methodChannel;
  private EventChannel eventChannel;
  private Context context;
  private Activity activity;
  private KBeaconsMgr mBeaconsMgr;
  private HashMap<String, KBeacon> mBeaconsDictory = new HashMap<>(50);;
  private KBeacon[] mBeaconsArray;
  SharedPreferenceMgr mPref;
  private KBConnState nDeviceConnState = KBConnState.Disconnected;

  private EventChannel.EventSink eventSink = null;

  private final static String TAG = "Beacon.ScanAct";//DeviceScanActivity.class.getSimpleName();
  private static String LOG_TAG = "DeviceScanActivity";
  private final static String MY_TAG = "Flo";
  private int mScanFailedContinueNum = 0;
  private final static int  MAX_ERROR_SCAN_NUMBER = 2;



  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    Log.e(TAG, "log");
    methodChannel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "kbeaconMethodChannel");
    eventChannel = new EventChannel(flutterPluginBinding.getBinaryMessenger(), "kbeaconEventChannel");
    methodChannel.setMethodCallHandler(this);
    eventChannel.setStreamHandler(this);
    context = flutterPluginBinding.getApplicationContext();

    mPref = SharedPreferenceMgr.shareInstance(context);
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    switch(call.method){
      case "getPlatformVersion":
        result.success("Modified Android " + android.os.Build.VERSION.RELEASE);
        break;
//      case "initPlugin":
//        String res1 = initPlugin();
//        result.success(res1);
//        break;
      case "requestCoarseLocationPermission":
        requestCoarseLocationPermission();
        result.success(null);
        break;
      case "requestFineLocationPermission":
        requestFineLocationPermission();
        result.success(null);
        break;
      case "requestBluetoothScanPermission":
        requestBluetoothScanPermission();
        result.success(null);
        break;
      case "requestBluetoothConnectionPermission":
        requestBluetoothConnectionPermission();
        result.success(null);
        break;
      case "startScanning":
        String res2 = startScanning();
        result.success(res2);
        break;
      case "scanResults":
//        scanResults();
        break;
      case "connect":
        String connectToMacAddress = call.argument("macAddress");
        String res3 = connect(connectToMacAddress);
        result.success(res3);
        break;
      case "disconnect":
        String disconnectFromMacAddress = call.argument("macAddress");
        String res4 = disconnect(disconnectFromMacAddress);
        result.success(res4);
        break;
      case "enableButtonTrigger":
        String enableButtonTriggerMacAddress = call.argument("macAddress");
        String res5 = enableButtonTrigger(enableButtonTriggerMacAddress);
        result.success(res5);
        break;
      default:
        result.notImplemented();
    }
//    if (call.method.equals("getPlatformVersion")) {
//      result.success("Android " + android.os.Build.VERSION.RELEASE);
//    } else {
//      result.notImplemented();
//    }
  }

  public String connect(String macAddress){
    BluetoothAdapter adapter = BluetoothAdapter.getDefaultAdapter();
    BluetoothDevice device = adapter.getRemoteDevice(macAddress);
    KBeacon mBeacon = new KBeacon(macAddress, context);
    try {
      Class<KBeacon> clsBeacon = null;
      clsBeacon = (Class<KBeacon>) Class.forName("com.kkmcn.kbeaconlib2.KBeacon");
      Method method = clsBeacon.getDeclaredMethod("attach2Device", BluetoothDevice.class, KBeaconsMgr.class);
      method.setAccessible(true);
      method.invoke(mBeacon, device, null);
    } catch (Exception e) {
      e.printStackTrace();
    }
    boolean res = mBeacon.connect(mPref.getPassword(macAddress), 10*1000, this);
    if(res){
      mBeaconsDictory.put(mBeacon.getMac(), mBeacon);
      return "connected";
    }
    return "disconnected";
  }

  public String disconnect(String macAddress){
//    BluetoothAdapter adapter = BluetoothAdapter.getDefaultAdapter();
//    BluetoothDevice device = adapter.getRemoteDevice(macAddress);
//    KBeacon mBeacon = new KBeacon(macAddress, context);
//    try {
//      Class<KBeacon> clsBeacon = null;
//      clsBeacon = (Class<KBeacon>) Class.forName("com.kkmcn.kbeaconlib2.KBeacon");
//      Method method = clsBeacon.getDeclaredMethod("attach2Device", BluetoothDevice.class, KBeaconsMgr.class);
//      method.setAccessible(true);
//      method.invoke(mBeacon, device, null);
//    } catch (Exception e) {
//      e.printStackTrace();
//    }
    KBeacon mBeacon = mBeaconsDictory.get(macAddress);
    mBeacon.disconnect();
    mBeaconsDictory.remove(mBeacon);
    return "disconnected";
  }

  // The device always broadcast UUID B9407F30-F5F8-466E-AFF9-25556B57FE67. When device detects button press,
  // it triggers the broadcast of the iBeacon message(uuid=B9407F30-F5F8-466E-AFF9-25556B570001) in Slot1,
  // and the iBeacon broadcast duration is 10 seconds.
  public String enableButtonTrigger(String macAddress) {

    KBeacon mBeacon = mBeaconsDictory.get(macAddress);

    if (!mBeacon.isConnected()) {
      Log.v(TAG,"Device is not connected");
      return "Device is not connected";
    }

    else Log.v(TAG, "Device connected");

    //check device capability
    final int nTriggerType = KBTriggerType.BtnSingleClick;
    final KBCfgCommon oldCommonCfg = (KBCfgCommon)mBeacon.getCommonCfg();
    if (oldCommonCfg != null && !oldCommonCfg.isSupportButton())
    {
      Log.v(TAG, "device is not support humidity");
      return "device is not support humidity";
    }

    //set slot0 to always advertisement
    final KBCfgAdvIBeacon iBeaconAdv = new KBCfgAdvIBeacon();
    iBeaconAdv.setSlotIndex(0);  //reuse previous slot
    iBeaconAdv.setAdvPeriod(1280f);
    iBeaconAdv.setAdvMode(KBAdvMode.Legacy);
    iBeaconAdv.setTxPower(KBAdvTxPower.RADIO_Neg4dBm);
    iBeaconAdv.setAdvConnectable(true);
    iBeaconAdv.setAdvTriggerOnly(false);  //always advertisement
    iBeaconAdv.setUuid("B9407F30-F5F8-466E-AFF9-25556B57FE67");
    iBeaconAdv.setMajorID(12);
    iBeaconAdv.setMinorID(10);

    //set slot 1 to trigger adv information
    final KBCfgAdvIBeacon triggerAdv = new KBCfgAdvIBeacon();
    triggerAdv.setSlotIndex(1);
    triggerAdv.setAdvPeriod(211.25f);
    triggerAdv.setAdvMode(KBAdvMode.Legacy);
    triggerAdv.setTxPower(KBAdvTxPower.RADIO_Pos4dBm);
    triggerAdv.setAdvConnectable(false);
    triggerAdv.setAdvTriggerOnly(true);  //trigger only advertisement
    triggerAdv.setUuid("B9407F30-F5F8-466E-AFF9-25556B570001");
    triggerAdv.setMajorID(1);
    triggerAdv.setMinorID(1);

    //set trigger type
    KBCfgTrigger btnTriggerPara = new KBCfgTrigger(0, KBTriggerType.BtnSingleClick);
    btnTriggerPara.setTriggerAdvChangeMode(0);
    btnTriggerPara.setTriggerAction(KBTriggerAction.Report2App);
    btnTriggerPara.setTriggerAdvSlot(1);
    btnTriggerPara.setTriggerAdvTime(10);

    //enable push button trigger
//    mTriggerButton.setEnabled(false);
    ArrayList<KBCfgBase> cfgList = new ArrayList<>(2);
    cfgList.add(iBeaconAdv);
    cfgList.add(triggerAdv);
    cfgList.add(btnTriggerPara);
    mBeacon.modifyConfig(cfgList, new KBeacon.ActionCallback() {
      public void onActionComplete(boolean bConfigSuccess, KBException error) {
//        mTriggerButton.setEnabled(true);
        if (bConfigSuccess) {
          Log.v(TAG, "enable push button trigger success");
          mBeacon.subscribeSensorDataNotify(nTriggerType, KbeaconPlugin.this, new KBeacon.ActionCallback() {
            @Override
            public void onActionComplete(boolean bConfigSuccess, KBException error) {
              if (bConfigSuccess) {
                Log.v(TAG, "subscribe button trigger event success");
              } else {
                Log.v(TAG, "subscribe button trigger event failed");
              }
            }
          });
          //return "enable push button trigger success";
        } else {
          Log.v(TAG, "enable push button trigger error:" + error.errorCode);
          //return "enable push button trigger error";
        }
      }
    });
    return "";
  }

  //handle trigger event notify
  public void onNotifyDataReceived(KBeacon beacon, int nEventType, byte[] sensorData)
  {
    Log.v(TAG, "Receive trigger notify event:" + nEventType);
//    eventSink
    eventSink.success("tap");
  }


  public void requestCoarseLocationPermission(){
    if (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION)
            != PackageManager.PERMISSION_GRANTED) {
      ActivityCompat.requestPermissions(activity,
              new String[]{Manifest.permission.ACCESS_COARSE_LOCATION}, 0);
    }
  }

  public void requestFineLocationPermission(){
    //for android10, the app need fine location permission for BLE scanning
    if (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION)
            != PackageManager.PERMISSION_GRANTED) {
      ActivityCompat.requestPermissions(activity,
              new String[]{Manifest.permission.ACCESS_FINE_LOCATION}, 0);
    }
  }

  public void requestBluetoothScanPermission(){
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
    {
      if (ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_SCAN) != PackageManager.PERMISSION_GRANTED) {
        ActivityCompat.requestPermissions(activity, new String[]{Manifest.permission.BLUETOOTH_SCAN}, 0);
      }
    }
  }

  public void requestBluetoothConnectionPermission(){
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
    {
      if (ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
        ActivityCompat.requestPermissions(activity, new String[]{Manifest.permission.BLUETOOTH_CONNECT}, 0);
      }
    }
  }

  public String initPlugin(){
    //for android6, the app need coarse location permission for BLE scanning
    if (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION)
            != PackageManager.PERMISSION_GRANTED) {
      ActivityCompat.requestPermissions(activity,
              new String[]{Manifest.permission.ACCESS_COARSE_LOCATION}, 0);
    }
//for android10, the app need fine location permission for BLE scanning
    if (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION)
            != PackageManager.PERMISSION_GRANTED) {
      ActivityCompat.requestPermissions(activity,
              new String[]{Manifest.permission.ACCESS_FINE_LOCATION}, 0);
    }
//for android 12, the app need declare follow permissions
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
    {
      if (ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_SCAN) != PackageManager.PERMISSION_GRANTED) {
        ActivityCompat.requestPermissions(activity, new String[]{Manifest.permission.BLUETOOTH_SCAN}, 0);
      }

      if (ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
        ActivityCompat.requestPermissions(activity, new String[]{Manifest.permission.BLUETOOTH_CONNECT}, 0);
      }
    }
    mBeaconsMgr = KBeaconsMgr.sharedBeaconManager(context);
    if(mBeaconsMgr == null)
      return "Make sure the phone supports BLE function";
    return "ok";
  }

  public String startScanning(){
    /// Initialize KBeacons manager instance
    mBeaconsMgr = KBeaconsMgr.sharedBeaconManager(context);
    if (mBeaconsMgr == null)
    {
      return "Make sure the phone supports BLE function";
    }

    /// Start KBeacons scanning
    mBeaconsMgr.delegate = this;
    int nStartScan = mBeaconsMgr.startScanning();
    if (nStartScan == 0)
    {
      return "start scan success";
    }
    else if (nStartScan == KBeaconsMgr.SCAN_ERROR_BLE_NOT_ENABLE) {
      return "BLE function is not enable";
    }
    else if (nStartScan == KBeaconsMgr.SCAN_ERROR_NO_PERMISSION) {
      return "BLE scanning has no location permission";
    }
    else
    {
      return "BLE scanning unknown error";
    }
  }


  //example for print all scanned packet
  KBeaconsMgr.KBeaconMgrDelegate beaconMgrDelegate = new KBeaconsMgr.KBeaconMgrDelegate() {
    //get advertisement packet during scanning callback
    public void onBeaconDiscovered(KBeacon[] beacons) {
      Log.v(LOG_TAG, beacons.length + " lungime");
      for (KBeacon beacon : beacons) {
        //get beacon adv common info
        Log.v(LOG_TAG, "beacon mac:" + beacon.getMac());
        Log.v(LOG_TAG, "beacon name:" + beacon.getName());
        Log.v(LOG_TAG, "beacon rssi:" + beacon.getRssi());

        //get adv packet
        for (KBAdvPacketBase advPacket : beacon.allAdvPackets()) {
          switch (advPacket.getAdvType()) {
            case KBAdvType.IBeacon: {
              KBAdvPacketIBeacon advIBeacon = (KBAdvPacketIBeacon) advPacket;
              Log.v(LOG_TAG, "iBeacon uuid:" + advIBeacon.getUuid());
              Log.v(LOG_TAG, "iBeacon major:" + advIBeacon.getMajorID());
              Log.v(LOG_TAG, "iBeacon minor:" + advIBeacon.getMinorID());
              break;
            }

            case KBAdvType.EddyTLM: {
              KBAdvPacketEddyTLM advTLM = (KBAdvPacketEddyTLM) advPacket;
              Log.v(LOG_TAG, "TLM battery:" + advTLM.getBatteryLevel());
              Log.v(LOG_TAG, "TLM Temperature:" + advTLM.getTemperature());
              Log.v(LOG_TAG, "TLM adv count:" + advTLM.getAdvCount());
              break;
            }

            case KBAdvType.Sensor: {
              KBAdvPacketSensor advSensor = (KBAdvPacketSensor) advPacket;
              Log.v(LOG_TAG, "Sensor battery:" + advSensor.getBatteryLevel());
              Log.v(LOG_TAG, "Sensor temp:" + advSensor.getTemperature());

              //device that has acc sensor
              KBAccSensorValue accPos = advSensor.getAccSensor();
              if (accPos != null) {
                String strAccValue = String.format(Locale.ENGLISH, "x:%d; y:%d; z:%d",
                        accPos.xAis, accPos.yAis, accPos.zAis);
                Log.v(LOG_TAG, "Sensor Acc:" + strAccValue);
              }

              //device that has humidity sensor
              if (advSensor.getHumidity() != null) {
                Log.v(LOG_TAG, "Sensor humidity:" + advSensor.getHumidity());
              }

              //device that has cutoff sensor
              if (advSensor.getWatchCutoff() != null) {
                Log.v(LOG_TAG, "cutoff flag:" + advSensor.getWatchCutoff());
              }

              //device that has PIR sensor
              if (advSensor.getPirIndication() != null) {
                Log.v(LOG_TAG, "pir indication:" + advSensor.getPirIndication());
              }
              break;
            }

            case KBAdvType.EddyUID: {
              KBAdvPacketEddyUID advUID = (KBAdvPacketEddyUID) advPacket;
              Log.v(LOG_TAG, "UID Nid:" + advUID.getNid());
              Log.v(LOG_TAG, "UID Sid:" + advUID.getSid());
              break;
            }

            case KBAdvType.EddyURL: {
              KBAdvPacketEddyURL advURL = (KBAdvPacketEddyURL) advPacket;
              Log.v(LOG_TAG, "URL:" + advURL.getUrl());
              break;
            }

            case KBAdvType.System: {
              KBAdvPacketSystem advSystem = (KBAdvPacketSystem) advPacket;
              Log.v(LOG_TAG, "System mac:" + advSystem.getMacAddress());
              Log.v(LOG_TAG, "System model:" + advSystem.getModel());
              Log.v(LOG_TAG, "System batt:" + advSystem.getBatteryPercent());
              Log.v(LOG_TAG, "System ver:" + advSystem.getVersion());
              break;
            }

            default:
              break;
          }
        }

        //clear all buffered packet
        beacon.removeAdvPacket();
      }
    }

    public void onCentralBleStateChang(int nNewState) {
      if (nNewState == KBeaconsMgr.BLEStatePowerOff)
      {
        Log.e(LOG_TAG, "BLE function is power off");
      }
      else if (nNewState == KBeaconsMgr.BLEStatePowerOn)
      {
        Log.e(LOG_TAG, "BLE function is power on");
      }
    }

    public void onScanFailed(int errorCode) {
      Log.e(LOG_TAG, "Start N scan failed：" + errorCode);
      if (mScanFailedContinueNum >= MAX_ERROR_SCAN_NUMBER){
        Log.e("ERROR: ", "scan encount error, error time:" + mScanFailedContinueNum);
      }
      mScanFailedContinueNum++;
    }
  };


  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    methodChannel.setMethodCallHandler(null);
  }

  @Override
  public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
    activity = binding.getActivity();
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {

  }

  @Override
  public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {

  }

  @Override
  public void onDetachedFromActivity() {

  }

  @Override
  public void onBeaconDiscovered(KBeacon[] beacons) {
    Log.e(TAG, "gasit");
    for (KBeacon pBeacons: beacons)
    {
      mBeaconsDictory.put(pBeacons.getMac(), pBeacons);
      Log.e(LOG_TAG, (beacons != null ? beacons.length : 0) + " lungime");
      for (KBeacon beacon : beacons) {
        //get beacon adv common info
        Log.e(LOG_TAG, "beacon mac:" + beacon.getMac());
        Log.e(LOG_TAG, "beacon name:" + beacon.getName());
        Log.e(LOG_TAG, "beacon rssi:" + beacon.getRssi());
      }
    }
    if (mBeaconsDictory.size() > 0) {
      mBeaconsArray = new KBeacon[mBeaconsDictory.size()];
      mBeaconsDictory.values().toArray(mBeaconsArray);
//      mDevListAdapter.notifyDataSetChanged();
    }
  }

  @Override
  public void onCentralBleStateChang(int nNewState) {
    Log.e(TAG, "centralBleStateChang：" + nNewState);
  }

  @Override
  public void onScanFailed(int errorCode) {
    Log.e(TAG, "Start N scan failed：" + errorCode);
    if (mScanFailedContinueNum >= MAX_ERROR_SCAN_NUMBER){
      Log.e(TAG, "scan encount error, error time:" + mScanFailedContinueNum);
    }
    mScanFailedContinueNum++;
  }

  @Override
  public void onListen(Object arguments, EventChannel.EventSink events) {
    this.eventSink = events;
  }

  @Override
  public void onCancel(Object arguments) {
    eventSink = null;
  }

  @Override
  public void onConnStateChange(KBeacon beacon, KBConnState state, int nReason) {
    if (state == KBConnState.Connected)
    {
      Log.v(LOG_TAG, "device has connected");
//      invalidateOptionsMenu();

//      mDownloadButton.setEnabled(true);
//
//      updateDeviceToView();
//
      nDeviceConnState = state;
    }
    else if (state == KBConnState.Connecting)
    {
      Log.v(LOG_TAG, "device start connecting");
//      invalidateOptionsMenu();

      nDeviceConnState = state;
    }
    else if (state == KBConnState.Disconnecting) {
      Log.e(LOG_TAG, "connection error, now disconnecting");
    }
    else
    {
      if (nDeviceConnState == KBConnState.Connecting)
      {
        if (nReason == KBConnectionEvent.ConnAuthFail)
        {
//          final EditText inputServer = new EditText(this);
//          AlertDialog.Builder builder = new AlertDialog.Builder(this);
//          builder.setTitle(getString(R.string.auth_error_title));
//          builder.setView(inputServer);
//          builder.setNegativeButton(R.string.Dialog_Cancel, null);
//          builder.setPositiveButton(R.string.Dialog_OK, null);
//          final AlertDialog alertDialog = builder.create();
//          alertDialog.show();
//
//          alertDialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener(new View.OnClickListener() {
//            @Override
//            public void onClick(View v) {
//              String strNewPassword = inputServer.getText().toString().trim();
//              if (strNewPassword.length() < 8|| strNewPassword.length() > 16)
//              {
//                Toast.makeText(DevicePannelActivity.this,
//                        R.string.connect_error_auth_format,
//                        Toast.LENGTH_SHORT).show();
//              }else {
//                mPref.setPassword(mDeviceAddress, strNewPassword);
//                alertDialog.dismiss();
//              }
//            }
//          });
        }
        else
        {
//          toastShow("connect to device failed, reason:" + nReason);
        }
      }

//      mDownloadButton.setEnabled(false);
      Log.e(LOG_TAG, "device has disconnected:" +  nReason);
//      invalidateOptionsMenu();
    }
  }
}
