import React, { useCallback, useState } from "react";
import {
  View,
  Text,
  ScrollView,
  StyleSheet,
  TouchableOpacity,
  Alert,
  Platform,
  Linking,
  ActivityIndicator,
} from "react-native";
import { router, useFocusEffect } from "expo-router";
import { SafeAreaView } from "react-native-safe-area-context";
import { Colors } from "../../constants/colors";
import { FontFamily, FontSize } from "../../constants/typography";
import { useAuth } from "../../hooks/useAuth";
import { api } from "../../services/api";

interface CheckIn {
  checked_in_at: string;
  event: {
    title: string;
    totem_slug: string;
    slug: string;
  };
}

function getInitials(name: string | null, email: string | null): string {
  if (name) return name.split(" ").map((n) => n[0]).join("").toUpperCase().slice(0, 2);
  if (email) return email[0].toUpperCase();
  return "?";
}

function MenuRow({ label, value, onPress, destructive }: {
  label: string;
  value?: string;
  onPress?: () => void;
  destructive?: boolean;
}) {
  return (
    <TouchableOpacity style={styles.menuRow} onPress={onPress} activeOpacity={0.7}>
      <Text style={[styles.menuLabel, destructive && styles.menuLabelDestructive]}>
        {label}
      </Text>
      {value && <Text style={styles.menuValue}>{value}</Text>}
      {onPress && !destructive && <Text style={styles.menuChevron}>›</Text>}
    </TouchableOpacity>
  );
}

export default function MeScreen() {
  const { user, signOut, deleteAccount, refreshUser } = useAuth();
  const [checkIns, setCheckIns] = useState<CheckIn[]>([]);

  useFocusEffect(useCallback(() => { refreshUser(); }, [refreshUser]));
  const [showCheckIns, setShowCheckIns] = useState(false);
  const [checkInsLoading, setCheckInsLoading] = useState(false);

  async function loadCheckIns() {
    setCheckInsLoading(true);
    try {
      const res = await api.get<{ check_ins: CheckIn[] }>("/api/v1/me/check_ins");
      setCheckIns(res.check_ins);
    } catch {}
    finally {
      setCheckInsLoading(false);
    }
  }

  function handleCheckInHistoryPress() {
    if (!showCheckIns) {
      loadCheckIns();
    }
    setShowCheckIns((v) => !v);
  }

  function handleSignOut() {
    if (Platform.OS === "web") {
      if (window.confirm("Are you sure you want to sign out?")) signOut();
      return;
    }
    Alert.alert("Sign out", "Are you sure you want to sign out?", [
      { text: "Cancel", style: "cancel" },
      { text: "Sign out", style: "destructive", onPress: signOut },
    ]);
  }

  function handleDeleteAccount() {
    if (Platform.OS === "web") {
      if (window.confirm("This will permanently delete your account and all your data. This cannot be undone.")) deleteAccount();
      return;
    }
    Alert.alert(
      "Delete account",
      "This will permanently delete your account and all your data. This cannot be undone.",
      [
        { text: "Cancel", style: "cancel" },
        { text: "Delete", style: "destructive", onPress: deleteAccount },
      ]
    );
  }

  if (!user) {
    return (
      <SafeAreaView style={styles.container}>
        <ActivityIndicator color={Colors.ember} style={{ flex: 1 }} />
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView contentContainerStyle={styles.scroll}>
        <View style={styles.header}>
          <Text style={styles.eyebrow}>ME</Text>
          <Text style={styles.title}>Your page</Text>
        </View>

        {/* Profile card */}
        <View style={styles.profileCard}>
          <View style={styles.avatar}>
            <Text style={styles.avatarText}>{getInitials(user.name, user.email)}</Text>
          </View>
          <View style={styles.profileInfo}>
            <Text style={styles.profileName}>{user.name ?? user.email}</Text>
            {user.name && user.email ? (
              <Text style={styles.profileEmail}>{user.email}</Text>
            ) : null}
            <Text style={styles.profileMethod}>
              {user.auth_method === "google" ? "● Signed in with Google" : "Email"}
            </Text>
          </View>
        </View>

        {/* Host events row */}
        {user.is_host && user.host_sso_url && (
          <View style={[styles.menuSection, { marginBottom: 16 }]}>
            <MenuRow
              label="Manage your hosted events"
              onPress={() => Linking.openURL(user.host_sso_url!)}
            />
          </View>
        )}

        {/* Menu */}
        <View style={styles.menuSection}>
          <MenuRow
            label="Favorites & Follows"
            onPress={() => router.push("/(app)/signals")}
          />
          <MenuRow
            label={`Check-in history${checkIns.length > 0 ? ` · ${checkIns.length}` : ""}`}
            onPress={handleCheckInHistoryPress}
          />
          {showCheckIns && (
            <View style={styles.checkInsContainer}>
              {checkInsLoading ? (
                <ActivityIndicator color={Colors.ember} />
              ) : checkIns.length === 0 ? (
                <Text style={styles.checkInsEmpty}>No check-ins yet.</Text>
              ) : (
                checkIns.map((ci, idx) => (
                  <View key={idx} style={styles.checkInRow}>
                    <Text style={styles.checkInTitle}>{ci.event.title}</Text>
                    <Text style={styles.checkInDate}>
                      {new Date(ci.checked_in_at).toLocaleDateString("en-US", {
                        month: "short",
                        day: "numeric",
                        year: "numeric",
                      })}
                    </Text>
                  </View>
                ))
              )}
            </View>
          )}
          <MenuRow
            label={`Notifications · ${user.notification_prefs?.all !== false ? "On" : "Off"}`}
            onPress={() => router.push("/(app)/signals")}
          />
          <MenuRow
            label="Data & privacy"
            onPress={() => Linking.openURL("https://signalfire.live/privacy")}
          />
          <MenuRow
            label="Send feedback"
            onPress={() => Linking.openURL("mailto:hello@signalfire.live?subject=App feedback")}
          />
        </View>

        {/* Sign out */}
        <View style={[styles.menuSection, { marginTop: 24 }]}>
          <TouchableOpacity style={styles.signOutButton} onPress={handleSignOut}>
            <Text style={styles.signOutText}>Sign out</Text>
          </TouchableOpacity>
        </View>

        {/* Delete account */}
        <TouchableOpacity style={styles.deleteButton} onPress={handleDeleteAccount}>
          <Text style={styles.deleteText}>Delete account</Text>
        </TouchableOpacity>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.paper },
  scroll: { paddingHorizontal: 20, paddingBottom: 60 },
  header: { paddingTop: 20, marginBottom: 20 },
  eyebrow: {
    fontFamily: FontFamily.mono,
    fontSize: FontSize.xs,
    color: Colors.stone,
    letterSpacing: 1,
    marginBottom: 4,
  },
  title: {
    fontFamily: FontFamily.sansSemiBold,
    fontSize: FontSize.xxl,
    color: Colors.ink,
  },
  profileCard: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: Colors.white,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: Colors.border,
    padding: 16,
    marginBottom: 24,
    gap: 14,
  },
  avatar: {
    width: 52,
    height: 52,
    borderRadius: 26,
    backgroundColor: Colors.stone,
    alignItems: "center",
    justifyContent: "center",
  },
  avatarText: {
    fontFamily: FontFamily.sansSemiBold,
    fontSize: FontSize.lg,
    color: Colors.white,
  },
  profileInfo: { flex: 1 },
  profileName: {
    fontFamily: FontFamily.sansSemiBold,
    fontSize: FontSize.base,
    color: Colors.ink,
  },
  profileEmail: {
    fontFamily: FontFamily.sans,
    fontSize: FontSize.sm,
    color: Colors.stone,
    marginTop: 2,
  },
  profileMethod: {
    fontFamily: FontFamily.sans,
    fontSize: FontSize.sm,
    color: Colors.muted,
    marginTop: 2,
  },
  menuSection: {
    backgroundColor: Colors.white,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: Colors.border,
    overflow: "hidden",
  },
  menuRow: {
    flexDirection: "row",
    alignItems: "center",
    paddingHorizontal: 16,
    paddingVertical: 14,
    borderBottomWidth: 1,
    borderBottomColor: Colors.border,
  },
  menuLabel: {
    flex: 1,
    fontFamily: FontFamily.sans,
    fontSize: FontSize.base,
    color: Colors.ink,
  },
  menuLabelDestructive: {
    color: "#c0392b",
  },
  menuValue: {
    fontFamily: FontFamily.sans,
    fontSize: FontSize.sm,
    color: Colors.stone,
    marginRight: 6,
  },
  menuChevron: {
    fontFamily: FontFamily.sans,
    fontSize: FontSize.lg,
    color: Colors.muted,
  },
  checkInsContainer: {
    paddingHorizontal: 16,
    paddingBottom: 12,
    borderBottomWidth: 1,
    borderBottomColor: Colors.border,
  },
  checkInsEmpty: {
    fontFamily: FontFamily.sans,
    fontSize: FontSize.sm,
    color: Colors.muted,
    paddingVertical: 8,
  },
  checkInRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    paddingVertical: 8,
    borderBottomWidth: 1,
    borderBottomColor: Colors.border,
  },
  checkInTitle: {
    fontFamily: FontFamily.sans,
    fontSize: FontSize.sm,
    color: Colors.ink,
    flex: 1,
  },
  checkInDate: {
    fontFamily: FontFamily.sans,
    fontSize: FontSize.sm,
    color: Colors.stone,
  },
  signOutButton: {
    paddingHorizontal: 16,
    paddingVertical: 14,
    alignItems: "center",
  },
  signOutText: {
    fontFamily: FontFamily.sans,
    fontSize: FontSize.base,
    color: Colors.ink,
  },
  deleteButton: {
    paddingVertical: 16,
    alignItems: "center",
  },
  deleteText: {
    fontFamily: FontFamily.sans,
    fontSize: FontSize.base,
    color: Colors.ember,
  },
});
