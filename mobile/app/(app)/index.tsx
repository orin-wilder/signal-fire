import React, { useEffect } from "react";
import {
  View,
  Text,
  ScrollView,
  StyleSheet,
  TouchableOpacity,
  RefreshControl,
  ActivityIndicator,
} from "react-native";
import { router } from "expo-router";
import { SafeAreaView } from "react-native-safe-area-context";
import { Colors } from "../../constants/colors";
import { FontFamily, FontSize } from "../../constants/typography";
import { useHome, YoursItem, StPeteTotem, NextEvent } from "../../hooks/useHome";

function formatNextEvent(event: NextEvent): string {
  const d = new Date(event.start_time);
  const today = new Date();
  const tomorrow = new Date(today);
  tomorrow.setDate(today.getDate() + 1);

  const time = d.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" });
  const isToday = d.toDateString() === today.toDateString();
  const isTomorrow = d.toDateString() === tomorrow.toDateString();

  const dayLabel = isToday ? "Tonight" : isTomorrow ? "Tomorrow" : d.toLocaleDateString("en-US", { weekday: "short", month: "short", day: "numeric" });
  return `${dayLabel} · ${time}`;
}

function StarIcon({ filled }: { filled: boolean }) {
  return (
    <Text style={{ fontSize: 16, color: Colors.ink }}>
      {filled ? "★" : "☆"}
    </Text>
  );
}

function YoursTotemCard({ item }: { item: Extract<YoursItem, { type: "totem_favorite" }> }) {
  const { totem, next_event } = item;
  return (
    <TouchableOpacity
      style={styles.card}
      onPress={() => router.push(`/totem/${totem.slug}`)}
      activeOpacity={0.8}
    >
      <View style={styles.cardHeader}>
        <View style={styles.cardHeaderText}>
          <Text style={styles.eyebrow}>
            {totem.name.toUpperCase()}{totem.neighborhood ? ` · ${totem.neighborhood.toUpperCase()}` : ""}
          </Text>
        </View>
        <StarIcon filled={totem.favorited} />
      </View>
      {next_event ? (
        <Text style={styles.cardMeta}>{formatNextEvent(next_event)}</Text>
      ) : (
        <Text style={styles.cardMeta}>Nothing scheduled soon</Text>
      )}
    </TouchableOpacity>
  );
}

function YoursHostCard({ item }: { item: Extract<YoursItem, { type: "host_follow" }> }) {
  const { host, next_event } = item;
  return (
    <TouchableOpacity
      style={styles.card}
      onPress={() => host.slug ? router.push(`/host/${host.slug}`) : undefined}
      activeOpacity={0.8}
    >
      <View style={styles.cardHeader}>
        <View style={styles.cardHeaderText}>
          <Text style={styles.eyebrow}>FOLLOWING · {host.display_name.toUpperCase()}</Text>
        </View>
        <Text style={styles.followingBadge}>FOLLOWING</Text>
      </View>
      {next_event ? (
        <Text style={styles.cardMeta}>{next_event.title} · {formatNextEvent(next_event)}</Text>
      ) : (
        <Text style={styles.cardMeta}>Nothing scheduled soon</Text>
      )}
    </TouchableOpacity>
  );
}

function StPeteCard({ totem }: { totem: StPeteTotem }) {
  return (
    <TouchableOpacity
      style={[styles.card, totem.active_now && styles.cardActive]}
      onPress={() => router.push(`/totem/${totem.slug}`)}
      activeOpacity={0.8}
    >
      <View style={styles.cardHeader}>
        <View style={styles.cardHeaderText}>
          <Text style={styles.eyebrow}>
            {totem.name.toUpperCase()}{totem.neighborhood ? ` · ${totem.neighborhood.toUpperCase()}` : ""}
          </Text>
        </View>
        <StarIcon filled={totem.favorited} />
      </View>

      {totem.active_now && (
        <View style={styles.liveChip}>
          <Text style={styles.liveChipText}>● LIVE NOW</Text>
        </View>
      )}

      {totem.next_event ? (
        <>
          <Text style={styles.cardEventTitle}>{totem.next_event.title}</Text>
          <Text style={styles.cardMeta}>{formatNextEvent(totem.next_event)}</Text>
          {totem.next_event.recurrence_label && (
            <Text style={styles.cardRecurrence}>{totem.next_event.recurrence_label}</Text>
          )}
        </>
      ) : (
        <Text style={styles.cardMeta}>Quiet this week</Text>
      )}
    </TouchableOpacity>
  );
}

export default function HomeScreen() {
  const { sections, loading, refreshing, load, refresh } = useHome();

  useEffect(() => {
    load();
  }, [load]);

  const yoursItems = sections?.yours.visible ? sections.yours.items : [];
  const stPeteTotems = sections?.st_pete.totems ?? [];

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView
        contentContainerStyle={styles.scroll}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={refresh} tintColor={Colors.ember} />
        }
      >
        <View style={styles.header}>
          <Text style={styles.headerLabel}>ST. PETERSBURG · {new Date().toLocaleDateString("en-US", { weekday: "short", month: "short", day: "numeric" }).toUpperCase()}</Text>
          <Text style={styles.title}>Home.</Text>
        </View>

        {loading ? (
          <ActivityIndicator color={Colors.ember} style={{ marginTop: 40 }} />
        ) : (
          <>
            {/* Yours section — conditional */}
            {yoursItems.length > 0 && (
              <View style={styles.section}>
                <Text style={styles.sectionLabel}>YOURS</Text>
                {yoursItems.map((item, i) =>
                  item.type === "totem_favorite" ? (
                    <YoursTotemCard key={`fav-${item.totem.id}-${i}`} item={item} />
                  ) : (
                    <YoursHostCard key={`follow-${item.host.host_follow_id}-${i}`} item={item} />
                  )
                )}
              </View>
            )}

            {/* St. Pete section — always visible */}
            <View style={styles.section}>
              <Text style={styles.sectionLabel}>ST. PETE</Text>
              {stPeteTotems.length === 0 ? (
                <Text style={styles.emptyText}>No places listed yet.</Text>
              ) : (
                stPeteTotems.map((totem) => (
                  <StPeteCard key={totem.id} totem={totem} />
                ))
              )}
            </View>
          </>
        )}
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.paper },
  scroll: { paddingHorizontal: 20, paddingBottom: 40 },
  header: { paddingTop: 20, marginBottom: 20 },
  headerLabel: {
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
  section: { marginBottom: 28 },
  sectionLabel: {
    fontFamily: FontFamily.mono,
    fontSize: FontSize.xs,
    color: Colors.stone,
    letterSpacing: 1,
    marginBottom: 10,
  },
  card: {
    backgroundColor: Colors.white,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: Colors.border,
    padding: 14,
    marginBottom: 10,
  },
  cardActive: {
    backgroundColor: Colors.emberLight,
    borderColor: "#e8d5c4",
  },
  cardHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "flex-start",
    marginBottom: 6,
  },
  cardHeaderText: { flex: 1, marginRight: 8 },
  eyebrow: {
    fontFamily: FontFamily.mono,
    fontSize: FontSize.xs,
    color: Colors.stone,
    letterSpacing: 0.5,
  },
  followingBadge: {
    fontFamily: FontFamily.mono,
    fontSize: 9,
    color: Colors.stone,
    letterSpacing: 0.5,
  },
  liveChip: {
    alignSelf: "flex-start",
    backgroundColor: Colors.ember,
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 4,
    marginBottom: 6,
  },
  liveChipText: {
    fontFamily: FontFamily.mono,
    fontSize: FontSize.xs,
    color: Colors.white,
    letterSpacing: 0.5,
  },
  cardEventTitle: {
    fontFamily: FontFamily.sansSemiBold,
    fontSize: FontSize.lg,
    color: Colors.ink,
    marginBottom: 2,
  },
  cardMeta: {
    fontFamily: FontFamily.sans,
    fontSize: FontSize.sm,
    color: Colors.stone,
  },
  cardRecurrence: {
    fontFamily: FontFamily.sans,
    fontSize: FontSize.xs,
    color: Colors.stone,
    marginTop: 2,
  },
  emptyText: {
    fontFamily: FontFamily.sans,
    fontSize: FontSize.base,
    color: Colors.stone,
    paddingVertical: 20,
    textAlign: "center",
  },
});
