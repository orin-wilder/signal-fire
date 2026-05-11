import React, { useState, useRef } from "react";
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Alert,
} from "react-native";
import { router } from "expo-router";
import { SafeAreaView } from "react-native-safe-area-context";
import { CameraView, useCameraPermissions } from "expo-camera";
import { Colors } from "../../constants/colors";
import { FontFamily, FontSize } from "../../constants/typography";

const SIGNAL_FIRE_URL_PATTERN = /\/t\/([a-z0-9-]+)/;

export default function ScanScreen() {
  const [permission, requestPermission] = useCameraPermissions();
  const [scanned, setScanned] = useState(false);
  const hasNavigated = useRef(false);

  function handleBarCodeScanned({ data }: { data: string }) {
    if (scanned || hasNavigated.current) return;
    const match = data.match(SIGNAL_FIRE_URL_PATTERN);
    if (match) {
      hasNavigated.current = true;
      setScanned(true);
      router.push({ pathname: `/totem/${match[1]}`, params: { source: "scan" } });
      setTimeout(() => {
        setScanned(false);
        hasNavigated.current = false;
      }, 2000);
    } else {
      Alert.alert("Not a Signal Fire QR code", "Try scanning an orange totem QR code.");
    }
  }

  if (!permission) return <View style={styles.container} />;

  if (!permission.granted) {
    return (
      <SafeAreaView style={styles.container}>
        <View style={styles.permissionContainer}>
          <Text style={styles.permissionText}>
            Camera access is needed to scan totem QR codes.
          </Text>
          <TouchableOpacity style={styles.grantButton} onPress={requestPermission}>
            <Text style={styles.grantButtonText}>Allow camera access</Text>
          </TouchableOpacity>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <View style={styles.container}>
      <CameraView
        style={StyleSheet.absoluteFill}
        facing="back"
        barcodeScannerSettings={{ barcodeTypes: ["qr"] }}
        onBarcodeScanned={scanned ? undefined : handleBarCodeScanned}
      />

      {/* Header */}
      <SafeAreaView style={styles.overlay}>
        <View style={styles.header}>
          <Text style={styles.headerLabel}>SCAN A TOTEM</Text>
          <TouchableOpacity onPress={() => router.back()}>
            <Text style={styles.closeButton}>Close</Text>
          </TouchableOpacity>
        </View>

        {/* Scan frame */}
        <View style={styles.frameContainer}>
          <View style={styles.frame}>
            <View style={[styles.corner, styles.cornerTL]} />
            <View style={[styles.corner, styles.cornerTR]} />
            <View style={[styles.corner, styles.cornerBL]} />
            <View style={[styles.corner, styles.cornerBR]} />
            <View style={styles.scanLine} />
          </View>
        </View>

        {/* Bottom */}
        <View style={styles.bottom}>
          <Text style={styles.hint}>Align the totem QR code inside the frame.</Text>
        </View>
      </SafeAreaView>
    </View>
  );
}

const CORNER = 24;

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#000" },
  permissionContainer: {
    flex: 1,
    backgroundColor: Colors.paper,
    alignItems: "center",
    justifyContent: "center",
    paddingHorizontal: 28,
    gap: 20,
  },
  permissionText: {
    fontFamily: FontFamily.sans,
    fontSize: FontSize.base,
    color: Colors.ink,
    textAlign: "center",
  },
  grantButton: {
    backgroundColor: Colors.ember,
    borderRadius: 10,
    paddingVertical: 14,
    paddingHorizontal: 28,
  },
  grantButtonText: {
    fontFamily: FontFamily.sansSemiBold,
    fontSize: FontSize.base,
    color: Colors.white,
  },
  overlay: { flex: 1 },
  header: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    paddingHorizontal: 20,
    paddingTop: 8,
    paddingBottom: 12,
  },
  headerLabel: {
    fontFamily: FontFamily.mono,
    fontSize: FontSize.xs,
    color: "rgba(255,255,255,0.7)",
    letterSpacing: 1,
  },
  closeButton: {
    fontFamily: FontFamily.sansSemiBold,
    fontSize: FontSize.base,
    color: Colors.white,
  },
  frameContainer: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
  },
  frame: {
    width: 240,
    height: 240,
    position: "relative",
    alignItems: "center",
    justifyContent: "center",
  },
  corner: {
    position: "absolute",
    width: CORNER,
    height: CORNER,
    borderColor: Colors.white,
  },
  cornerTL: { top: 0, left: 0, borderTopWidth: 3, borderLeftWidth: 3 },
  cornerTR: { top: 0, right: 0, borderTopWidth: 3, borderRightWidth: 3 },
  cornerBL: { bottom: 0, left: 0, borderBottomWidth: 3, borderLeftWidth: 3 },
  cornerBR: { bottom: 0, right: 0, borderBottomWidth: 3, borderRightWidth: 3 },
  scanLine: {
    width: 200,
    height: 2,
    backgroundColor: Colors.ember,
    opacity: 0.9,
  },
  bottom: { padding: 28 },
  hint: {
    fontFamily: FontFamily.sans,
    fontSize: FontSize.sm,
    color: "rgba(255,255,255,0.8)",
    textAlign: "center",
  },
});
