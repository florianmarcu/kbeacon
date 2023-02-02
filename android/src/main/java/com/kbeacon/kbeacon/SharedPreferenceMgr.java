package com.kbeacon.kbeacon;

import android.content.Context;
import android.content.SharedPreferences;

public class SharedPreferenceMgr {
    private Context mContext;
    private final static String SETTING_INFO = "SETTING_INFO";
    private final static String FLD_VRY_CODE_NUM_VALUE = "FLD_VRY_CODE_NUM_VALUE";
    private final static String DEF_VRY_CODE_NUM = "0000000000000000";


    static private SharedPreferenceMgr sPrefMgr = null;
    SharedPreferences shareReference;

    static public synchronized SharedPreferenceMgr shareInstance(Context ctx){
        if (sPrefMgr == null){
            sPrefMgr = new SharedPreferenceMgr();
            sPrefMgr.initSetting(ctx);
        }

        return sPrefMgr;
    }

    private SharedPreferenceMgr(){
    }

    //初始化配置
    public void initSetting(Context ctx){
        mContext = ctx;
        shareReference = mContext.getSharedPreferences(SETTING_INFO, mContext.MODE_PRIVATE);
    }

    public void setPassword(String strMacAddress, String strPassword){

        SharedPreferences.Editor edit = shareReference.edit();
        edit.putString(FLD_VRY_CODE_NUM_VALUE + strMacAddress.toLowerCase(), strPassword);
        edit.apply();
    }

    public String getPassword(String strMacAddress){
        return shareReference.getString(FLD_VRY_CODE_NUM_VALUE+strMacAddress.toLowerCase(), DEF_VRY_CODE_NUM);
    }

}
