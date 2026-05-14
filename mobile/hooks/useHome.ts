import { useState, useCallback } from "react";
import { api } from "../services/api";

export interface NextEvent {
  id: number;
  title: string;
  start_time: string;
  recurrence_label: string | null;
}

export interface TotemItem {
  type: "totem_favorite";
  totem: {
    id: number;
    name: string;
    slug: string;
    neighborhood: string | null;
    character_description: string | null;
    favorited: boolean;
    totem_favorite_id: number;
  };
  next_event: NextEvent | null;
}

export interface HostItem {
  type: "host_follow";
  host: {
    display_name: string;
    slug: string | null;
    following: boolean;
    host_follow_id: number;
  };
  next_event: NextEvent | null;
}

export type YoursItem = TotemItem | HostItem;

export interface StPeteTotem {
  id: number;
  name: string;
  slug: string;
  neighborhood: string | null;
  character_description: string | null;
  active_now: boolean;
  favorited: boolean;
  totem_favorite_id: number | null;
  next_event: NextEvent | null;
}

export interface HomeSections {
  yours: { visible: true; items: YoursItem[] } | { visible: false };
  st_pete: { visible: true; totems: StPeteTotem[] };
  nearby: { visible: false; reason: string };
}

interface HomeResponse {
  sections: HomeSections;
}

export function useHome() {
  const [sections, setSections] = useState<HomeSections | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  const load = useCallback(async () => {
    try {
      const res = await api.get<HomeResponse>("/api/v1/home");
      setSections(res.sections);
    } catch {
      setSections(null);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, []);

  const refresh = useCallback(() => {
    setRefreshing(true);
    load();
  }, [load]);

  return { sections, loading, refreshing, load, refresh };
}
