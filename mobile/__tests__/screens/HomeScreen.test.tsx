jest.mock("../../services/api", () => ({
  api: { get: jest.fn() },
}));

jest.mock("expo-router", () => ({
  router: { push: jest.fn() },
}));

import React from "react";
import { ActivityIndicator } from "react-native";
import { render, screen, waitFor } from "@testing-library/react-native";
import { api } from "../../services/api";
import HomeScreen from "../../app/(app)/index";
import type { HomeSections } from "../../hooks/useHome";

const mockApi = api as jest.Mocked<typeof api>;

const nextWeek = new Date(Date.now() + 7 * 86400000).toISOString();

function makeResponse(overrides: Partial<HomeSections> = {}): { sections: HomeSections } {
  return {
    sections: {
      yours: { visible: false },
      st_pete: {
        visible: true,
        totems: [
          {
            id: 1,
            name: "Williams Park Lawn",
            slug: "williams-park-lawn",
            neighborhood: "Old Northeast",
            character_description: "Bodies in the air every Sunday.",
            active_now: false,
            favorited: false,
            totem_favorite_id: null,
            next_event: { id: 10, title: "Sunday Jam", start_time: nextWeek, recurrence_label: "Weekly on Sundays" },
          },
        ],
      },
      nearby: { visible: false, reason: "no_adjacent_cities" },
      ...overrides,
    },
  };
}

beforeEach(() => {
  jest.clearAllMocks();
});

describe("HomeScreen loading", () => {
  it("shows loading indicator while fetching", () => {
    mockApi.get.mockImplementationOnce(() => new Promise(() => {}));
    render(<HomeScreen />);
    expect(screen.UNSAFE_getByType(ActivityIndicator)).toBeTruthy();
  });
});

describe("HomeScreen St. Pete section", () => {
  it("renders totem names from st_pete section", async () => {
    mockApi.get.mockResolvedValueOnce(makeResponse());
    render(<HomeScreen />);
    await waitFor(() => {
      expect(screen.getByText("WILLIAMS PARK LAWN · OLD NORTHEAST")).toBeTruthy();
    });
  });

  it("renders ST. PETE section label", async () => {
    mockApi.get.mockResolvedValueOnce(makeResponse());
    render(<HomeScreen />);
    await waitFor(() => {
      expect(screen.getByText("ST. PETE")).toBeTruthy();
    });
  });

  it("shows next event title", async () => {
    mockApi.get.mockResolvedValueOnce(makeResponse());
    render(<HomeScreen />);
    await waitFor(() => {
      expect(screen.getByText("Sunday Jam")).toBeTruthy();
    });
  });

  it("shows LIVE NOW chip for active-now totem", async () => {
    const res = makeResponse();
    res.sections.st_pete.totems[0].active_now = true;
    mockApi.get.mockResolvedValueOnce(res);
    render(<HomeScreen />);
    await waitFor(() => {
      expect(screen.getByText("● LIVE NOW")).toBeTruthy();
    });
  });
});

describe("HomeScreen Yours section", () => {
  it("renders YOURS section when user has favorites", async () => {
    const res = makeResponse({
      yours: {
        visible: true,
        items: [
          {
            type: "totem_favorite",
            totem: {
              id: 2,
              name: "North Shore Courts",
              slug: "north-shore-courts",
              neighborhood: "North Shore",
              character_description: null,
              favorited: true,
              totem_favorite_id: 99,
            },
            next_event: { id: 20, title: "Sand Volleyball", start_time: nextWeek, recurrence_label: null },
          },
        ],
      },
    });
    mockApi.get.mockResolvedValueOnce(res);
    render(<HomeScreen />);
    await waitFor(() => {
      expect(screen.getByText("YOURS")).toBeTruthy();
      expect(screen.getByText("NORTH SHORE COURTS · NORTH SHORE")).toBeTruthy();
    });
  });

  it("renders host follow card in YOURS section", async () => {
    const res = makeResponse({
      yours: {
        visible: true,
        items: [
          {
            type: "host_follow",
            host: {
              display_name: "Amara Chen",
              slug: "amara-chen",
              following: true,
              host_follow_id: 7,
            },
            next_event: { id: 10, title: "Sunday Jam", start_time: nextWeek, recurrence_label: null },
          },
        ],
      },
    });
    mockApi.get.mockResolvedValueOnce(res);
    render(<HomeScreen />);
    await waitFor(() => {
      expect(screen.getByText("FOLLOWING · AMARA CHEN")).toBeTruthy();
    });
  });

  it("does not render YOURS section when yours.visible is false", async () => {
    mockApi.get.mockResolvedValueOnce(makeResponse({ yours: { visible: false } }));
    render(<HomeScreen />);
    await waitFor(() => screen.getByText("ST. PETE"));
    expect(screen.queryByText("YOURS")).toBeNull();
  });
});
