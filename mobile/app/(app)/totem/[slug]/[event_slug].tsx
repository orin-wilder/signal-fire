import React, { useEffect, useState } from "react";
import {
  View,
  Text,
  ScrollView,
  StyleSheet,
  TouchableOpacity,
  Linking,
  Share,
  ActivityIndicator,
  Alert,
} from "react-native";
import { useLocalSearchParams, router } from "expo-router";
import { SafeAreaView } from "react-native-safe-area-context";
import { Colors } from "../../../../constants/colors";
import { FontFamily, FontSize } from "../../../../constants/typography";
import { Event } from "../../../../hooks/useTotem";
import { CheckInButton } from "../../../../components/CheckInButton";
import { api, getToken } from "../../../../services/api";
import { posthog } from "../../../../services/analytics";

const PLATFORM_LABELS: Record<string, string> = {
  whatsapp: "WhatsApp",
  discord: "Discord",
  telegram: "Telegram",
  signal: "Signal",
  groupme: "GroupMe",
  slack: "Slack",
};

function formatDateTime(iso: string): string {
  const d = new Date(iso);
  return (
    d.toLocaleDateString("en-US", {
      weekday: "short",
      month: "short",
      day: "numeric",
    }) +
    " · " +
    d.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" })
  );
}

function formatTimeRange(start: string, end: string): string {
  const s = new Date(start).toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" });
  const e = new Date(end).toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" });
  return `${s} – ${e}`;
}

export default function EventDetailScreen() {
  const { slug, event_slug } = useLocalSearchParams<{ slug: string; event_slug: string }>();
  const [event, setEvent] = useState<Event | null>(null);
  const [loading, setLoading] = useState(true);
  const [checkInLoading, setCheckInLoading] = useState(false);
  const [followLoading, setFollowLoading] = useState(false);
  const [authenticated, setAuthenticated] = useState(false);

  useEffect(() => {
    async function load() {
      const token = await getToken();
      setAuthenticated(!!token);
      try {
        const res = await api.get<{ event: Event }>(
          `/api/v1/totems/${slug}/events/${event_slug}`,
          !!token
        );
        setEvent(res.event);
      } catch {
        setEvent(null);
      } finally {
        setLoading(false);
      }
    }
    load();
  }, [slug, event_slug]);

  async function handleCheckIn() {
    if (!event) return;
    posthog.capture("check_in_tapped", { event_id: event.id, totem_slug: slug });
    if (!authenticated) {
      Alert.alert(
        "Sign in to check in",
        "Create a free account to check in and track your history.",
        [
          { text: "Not now", style: "cancel" },
          { text: "Sign in", onPress: () => router.push("/(auth)/sign-up") },
        ]
      );
      return;
    }
    setCheckInLoading(true);
    try {
      const res = await api.post<{ checked_in: boolean; checked_in_at: string }>(
        `/api/v1/events/${event.id}/check_ins`,
        {}
      );
      setEvent((e) => e && { ...e, user_checked_in: true, checked_in_at: res.checked_in_at });
    } catch (e: any) {
      Alert.alert("Check-in failed", e?.body?.error ?? "Please try again.");
    } finally {
      setCheckInLoading(false);
    }
  }

  async function handleFollowToggle() {
    if (!event) return;
    if (!authenticated) {
      Alert.alert(
        "Sign in to follow",
        "Create a free account to follow hosts and get weekly updates.",
        [
          { text: "Not now", style: "cancel" },
          { text: "Sign in", onPress: () => router.push("/(auth)/sign-up") },
        ]
      );
      return;
    }
    setFollowLoading(true);
    try {
      if (event.following) {
        await api.delete(`/api/v1/host_follows/${event.host.host_follow_id}`);
        posthog.capture("host_unfollowed", { host_slug: event.host.slug });
        setEvent((e) => e && { ...e, following: false, host: { ...e.host, following: false, host_follow_id: null } });
      } else {
        const res = await api.post<{ id: number }>("/api/v1/host_follows", {
          host_user_id: event.host.id,
        });
        posthog.capture("host_followed", { host_slug: event.host.slug });
        setEvent((e) => e && { ...e, following: true, host: { ...e.host, following: true, host_follow_id: res.id } });
      }
    } catch {
      Alert.alert("Something went wrong", "Please try again.");
    } finally {
      setFollowLoading(false);
    }
  }

  async function saveToCalendar() {
    if (!event?.calendar_url) return;
    posthog.capture("event_calendar_saved", { event_id: event.id });
    Linking.openURL(event.calendar_url);
  }

  async function shareEvent() {
    if (!event?.share_url) return;
    posthog.capture("event_shared", { event_id: event.id });
    await Share.share({
      message: `${event.title} — ${event.share_url}`,
      url: event.share_url,
    });
  }

  if (loading) {
    return (
      <SafeAreaView style={styles.container}>
        <ActivityIndicator color={Colors.ember} style={{ flex: 1 }} />
      </SafeAreaView>
    );
  }

  if (!event) {
    return (
      <SafeAreaView style={styles.container}>
        <TouchableOpacity onPress={() => router.back()} style={styles.backButton}>
          <Text style={styles.backText}>‹ Back to board</Text>
        </TouchableOpacity>
        <Text style={styles.notFound}>Event not found</Text>
      </SafeAreaView>
    );
  }

  const isCancelled = event.status === "cancelled";
  const platformLabel = PLATFORM_LABELS[event.chat_platform] ?? event.chat_platform;
  const inWindow =
    event.window_state === "happening_now" ||
    event.window_state === "starting_soon" ||
    event.window_state === "just_ended";

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView contentContainerStyle={styles.scroll}>
        <TouchableOpacity onPress={() => router.back()} style={styles.backButton}>
          <Text style={styles.backText}>‹ Back to board</Text>
        </TouchableOpacity>

        {/* Cancelled banner */}
        {isCancelled && (
          <View style={styles.cancelledBanner}>
            <View style={styles.cancelledChip}>
              <Text style={styles.cancelledChipText}>CANCELLED</Text>
            </View>
            <Text style={styles.cancelledMessage}>
              This event has been cancelled by the host.
            </Text>
          </View>
        )}

        {/* Window state chip for active events */}
        {!isCancelled && event.window_state === "happening_now" && (
          <View style={styles.happeningChip}>
            <Text style={styles.happeningChipText}>HAPPENING NOW</Text>
          </View>
        )}

        {/* Title & meta */}
        <Text style={styles.title}>{event.title}</Text>
        <Text style={styles.meta}>
          {event.recurrence_label ?? formatDateTime(event.next_occurrence)}
        </Text>
        <Text style={styles.meta}>
          {formatTimeRange(event.start_time, event.end_time)}
        </Text>

        {/* Host row — name taps to HostPage + inline follow toggle */}
        <View style={styles.hostSection}>
          <Text style={styles.sectionLabel}>HOST</Text>
          <View style={styles.hostRow}>
            <TouchableOpacity
              style={styles.hostInfo}
              onPress={() => {
                if (event.host.slug) {
                  router.push(`/(app)/host/${event.host.slug}` as any);
                }
              }}
              activeOpacity={event.host.slug ? 0.7 : 1}
            >
              <Text style={styles.hostName}>{event.host.name}</Text>
              {event.host.blurb ? (
                <Text style={styles.hostBlurb}>{event.host.blurb}</Text>
              ) : null}
            </TouchableOpacity>

            <TouchableOpacity
              style={[styles.followBtn, event.following && styles.followBtnActive]}
              onPress={handleFollowToggle}
              disabled={followLoading}
              accessibilityLabel={event.following ? `Unfollow ${event.host.name}` : `Follow ${event.host.name}`}
              accessibilityRole="button"
            >
              <Text style={[styles.followBtnText, event.following && styles.followBtnTextActive]}>
                {event.following ? "Following" : "+ Follow"}
              </Text>
            </TouchableOpacity>
          </View>
        </View>

        {/* Description */}
        {event.description ? (
          <View style={styles.section}>
            <Text style={styles.sectionLabel}>DESCRIPTION</Text>
            <Text style={styles.body}>{event.description}</Text>
          </View>
        ) : null}

        {/* Community norms */}
        {event.community_norms ? (
          <View style={styles.section}>
            <Text style={styles.sectionLabel}>COMMUNITY NORMS</Text>
            <Text style={styles.body}>{event.community_norms}</Text>
          </View>
        ) : null}

        {/* CTAs */}
        {!isCancelled && inWindow && (
          <CheckInButton
            windowState={event.window_state}
            checkedIn={event.user_checked_in ?? false}
            checkedInAt={event.checked_in_at}
            loading={checkInLoading}
            onPress={handleCheckIn}
          />
        )}

        {event.chat_url ? (
          <TouchableOpacity
            style={[styles.secondaryButton, isCancelled && { marginTop: 20 }]}
            onPress={() => {
              posthog.capture("chat_link_tapped", { event_id: event.id, platform: event.chat_platform });
              Linking.openURL(event.chat_url!);
            }}
            activeOpacity={0.85}
          >
            <Text style={styles.secondaryButtonText}>
              {isCancelled ? `Open the ${platformLabel} group` : `Join on ${platformLabel}`}
            </Text>
          </TouchableOpacity>
        ) : null}

        {/* Save to calendar */}
        {!isCancelled && (
          <TouchableOpacity
            style={styles.secondaryButton}
            onPress={saveToCalendar}
            activeOpacity={0.85}
          >
            <Text style={styles.secondaryButtonText}>Save to my calendar</Text>
          </TouchableOpacity>
        )}

        {/* Share event */}
        <TouchableOpacity
          style={styles.secondaryButton}
          onPress={shareEvent}
          activeOpacity={0.85}
        >
          <Text style={styles.secondaryButtonText}>Share this event</Text>
        </TouchableOpacity>

        {isCancelled && (
          <Text style={styles.chatNote}>
            Group chat may still be active at host discretion.
          </Text>
        )}
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.paper },
  scroll: { paddingHorizontal: 20, paddingBottom: 60 },
  backButton: { paddingTop: 8, paddingBottom: 12 },
  backText: {
    fontFamily: FontFamily.sans,
    fontSize: FontSize.sm,
    color: Colors.stone,
  },
  notFound: {
    fontFamily: FontFamily.sans,
    fontSize: FontSize.base,
    color: Colors.stone,
    textAlign: "center",
    marginTop: 40,
  },
  cancelledBanner: {
    backgroundColor: "#fdf2f2",
    borderWidth: 1,
    borderColor: "#e74c3c",
    borderRadius: 8,
    padding: 14,
    marginBottom: 16,
  },
  cancelledChip: {
    alignSelf: "flex-start",
    backgroundColor: "#e74c3c",
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 4,
    marginBottom: 8,
  },
  cancelledChipText: {
    fontFamily: FontFamily.mono,
    fontSize: FontSize.xs,
    color: Colors.white,
    letterSpacing: 0.5,
  },
  cancelledMessage: {
    fontFamily: FontFamily.sans,
    fontSize: FontSize.sm,
    color: "#c0392b",
  },
  happeningChip: {
    alignSelf: "flex-start",
    backgroundColor: Colors.ember,
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 4,
    marginBottom: 10,
  },
  happeningChipText: {
    fontFamily: FontFamily.mono,
    fontSize: FontSize.xs,
    color: Colors.white,
    letterSpacing: 0.5,
  },
  title: {
    fontFamily: FontFamily.sansSemiBold,
    fontSize: FontSize.xxl,
    color: Colors.ink,
    marginBottom: 6,
    lineHeight: 32,
  },
  meta: {
    fontFamily: FontFamily.sans,
    fontSize: FontSize.sm,
    color: Colors.stone,
    marginBottom: 2,
  },
  hostSection: {
    marginTop: 24,
    marginBottom: 8,
  },
  hostRow: {
    flexDirection: "row",
    alignItems: "flex-start",
    justifyContent: "space-between",
    gap: 12,
  },
  hostInfo: { flex: 1 },
  hostName: {
    fontFamily: FontFamily.sansSemiBold,
    fontSize: FontSize.base,
    color: Colors.ink,
    marginBottom: 2,
  },
  hostBlurb: {
    fontFamily: FontFamily.sans,
    fontSize: FontSize.sm,
    color: Colors.stone,
    lineHeight: 20,
  },
  followBtn: {
    paddingHorizontal: 14,
    paddingVertical: 7,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: Colors.border,
    alignSelf: "flex-start",
  },
  followBtnActive: {
    backgroundColor: Colors.ink,
    borderColor: Colors.ink,
  },
  followBtnText: {
    fontFamily: FontFamily.sansSemiBold,
    fontSize: FontSize.sm,
    color: Colors.ink,
  },
  followBtnTextActive: {
    color: Colors.white,
  },
  section: { marginTop: 20 },
  sectionLabel: {
    fontFamily: FontFamily.mono,
    fontSize: FontSize.xs,
    color: Colors.stone,
    letterSpacing: 1,
    marginBottom: 8,
  },
  body: {
    fontFamily: FontFamily.sans,
    fontSize: FontSize.base,
    color: Colors.ink,
    lineHeight: 22,
  },
  secondaryButton: {
    borderWidth: 1,
    borderColor: Colors.border,
    borderRadius: 10,
    paddingVertical: 14,
    alignItems: "center",
    marginTop: 12,
    backgroundColor: Colors.white,
  },
  secondaryButtonText: {
    fontFamily: FontFamily.sansSemiBold,
    fontSize: FontSize.base,
    color: Colors.ink,
  },
  chatNote: {
    fontFamily: FontFamily.sans,
    fontSize: FontSize.sm,
    color: Colors.muted,
    textAlign: "center",
    marginTop: 8,
  },
});
