import { useEffect } from "react";
import { Linking, Platform } from "react-native";
import { Stack, router } from "expo-router";
import { posthog } from "../services/analytics";
import { useFonts } from "expo-font";
import {
  InstrumentSans_400Regular,
  InstrumentSans_500Medium,
  InstrumentSans_600SemiBold,
} from "@expo-google-fonts/instrument-sans";
import {
  JetBrainsMono_400Regular,
} from "@expo-google-fonts/jetbrains-mono";
import * as SplashScreen from "expo-splash-screen";
import * as Notifications from "expo-notifications";
import { StatusBar } from "expo-status-bar";

SplashScreen.preventAutoHideAsync();

if (Platform.OS === "android") {
  Notifications.setNotificationChannelAsync("default", {
    name: "Default",
    importance: Notifications.AndroidImportance.MAX,
    vibrationPattern: [0, 250, 250, 250],
  });
}

if (Platform.OS !== "web") {
  Notifications.setNotificationHandler({
    handleNotification: async () => ({
      shouldShowAlert: true,
      shouldShowBanner: true,
      shouldShowList: true,
      shouldPlaySound: true,
      shouldSetBadge: false,
    }),
  });
}

function handleNotificationData(data: Record<string, unknown> | undefined) {
  if (!data) return;

  // New V1.5 notifications carry a `type` field; older ones use `notification_type`.
  const type = (data.type || data.notification_type) as string | undefined;

  switch (type) {
    case "weekly_digest":
      posthog.capture("weekly_digest_opened");
      router.push("/(app)/");
      break;
    case "first_stranger":
      if (typeof data.sso_url === "string") {
        Linking.openURL(data.sso_url);
      }
      break;
    default:
      // Legacy event notifications and pre_event_reminder: route by slug if present
      if (data.totem_slug && data.event_slug) {
        router.push(`/(app)/totem/${data.totem_slug}/${data.event_slug}`);
      }
  }
}

export default function RootLayout() {
  const [fontsLoaded] = useFonts({
    InstrumentSans_400Regular,
    InstrumentSans_500Medium,
    InstrumentSans_600SemiBold,
    JetBrainsMono_400Regular,
    // InstrumentSerif loaded via system fallback if not available
  });

  useEffect(() => {
    if (fontsLoaded) {
      SplashScreen.hideAsync();
    }
  }, [fontsLoaded]);

  // Handle tap when app was open or backgrounded
  useEffect(() => {
    if (Platform.OS === "web") return;
    const sub = Notifications.addNotificationResponseReceivedListener((response) => {
      handleNotificationData(response.notification.request.content.data as Record<string, unknown>);
    });
    return () => sub.remove();
  }, []);

  // Handle tap when app was closed (cold start)
  useEffect(() => {
    if (Platform.OS === "web") return;
    Notifications.getLastNotificationResponseAsync().then((response) => {
      if (!response) return;
      handleNotificationData(response.notification.request.content.data as Record<string, unknown>);
    });
  }, []);

  if (!fontsLoaded) return null;

  return (
    <>
      <StatusBar style="dark" />
      <Stack screenOptions={{ headerShown: false }}>
        <Stack.Screen name="(auth)" />
        <Stack.Screen name="(app)" />
        <Stack.Screen name="totem" />
      </Stack>
    </>
  );
}
