import { Tabs } from "expo-router";
import { Text, View, StyleSheet } from "react-native";
import { Colors } from "../../constants/colors";
import { FontFamily, FontSize } from "../../constants/typography";

function TabIcon({ label, focused }: { label: string; focused: boolean }) {
  return (
    <Text style={[styles.icon, focused && styles.iconFocused]}>{label}</Text>
  );
}

function ScanIcon({ focused }: { focused: boolean }) {
  return (
    <View style={[styles.scanIconWrap, focused && styles.scanIconWrapFocused]}>
      <Text style={styles.scanIconText}>⬛</Text>
    </View>
  );
}

export default function AppLayout() {
  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarStyle: {
          backgroundColor: Colors.white,
          borderTopColor: Colors.border,
          borderTopWidth: 1,
        },
        tabBarActiveTintColor: Colors.ink,
        tabBarInactiveTintColor: Colors.muted,
        tabBarLabelStyle: {
          fontFamily: FontFamily.sans,
          fontSize: FontSize.xs,
        },
      }}
    >
      <Tabs.Screen
        name="index"
        options={{
          title: "Home",
          tabBarIcon: ({ focused }) => <TabIcon label="⌂" focused={focused} />,
        }}
      />
      <Tabs.Screen
        name="scan"
        options={{
          title: "Scan",
          tabBarIcon: ({ focused }) => <ScanIcon focused={focused} />,
          tabBarActiveTintColor: Colors.ember,
        }}
      />
      <Tabs.Screen
        name="me"
        options={{
          title: "Profile",
          tabBarIcon: ({ focused }) => <TabIcon label="◉" focused={focused} />,
        }}
      />
      {/* Hidden screens — not shown in tab bar */}
      <Tabs.Screen name="signals" options={{ href: null }} />
      <Tabs.Screen name="totem" options={{ href: null }} />
      <Tabs.Screen name="host" options={{ href: null }} />
    </Tabs>
  );
}

const styles = StyleSheet.create({
  icon: {
    fontSize: 18,
    color: Colors.muted,
  },
  iconFocused: {
    color: Colors.ink,
  },
  scanIconWrap: {
    width: 36,
    height: 36,
    borderRadius: 10,
    backgroundColor: Colors.border,
    alignItems: "center",
    justifyContent: "center",
    marginBottom: 2,
  },
  scanIconWrapFocused: {
    backgroundColor: Colors.ember,
  },
  scanIconText: {
    fontSize: 16,
    color: Colors.white,
  },
});
