jest.mock("../../hooks/useTotem", () => ({
  useTotem: jest.fn(),
}));

jest.mock("../../services/api", () => ({
  api: {
    post: jest.fn(),
    delete: jest.fn(),
  },
}));

import { posthog } from "../../services/analytics";

import React from "react";
import { render, screen, waitFor, fireEvent, act } from "@testing-library/react-native";
import { useLocalSearchParams, router } from "expo-router";
import { useTotem } from "../../hooks/useTotem";
import { api } from "../../services/api";
import TotemBoardScreen from "../../app/(app)/totem/[slug]";

const mockUseTotem = useTotem as jest.MockedFunction<typeof useTotem>;
const mockUseLocalSearchParams = useLocalSearchParams as jest.MockedFunction<typeof useLocalSearchParams>;
const mockRouter = router as jest.Mocked<typeof router>;
const mockApi = api as jest.Mocked<typeof api>;

const baseTotem = {
  id: 1,
  name: "Waterfront North",
  slug: "waterfront-north",
  location: "St. Petersburg",
  sublocation: null,
  active: true,
  empty: false,
  following: false,
  active_now: [],
  upcoming: [],
};

const defaultHook = {
  totem: baseTotem,
  loading: false,
  error: null,
  load: jest.fn(),
  toggleFollow: jest.fn(),
  setTotem: jest.fn(),
};

beforeEach(() => {
  jest.clearAllMocks();
  mockUseLocalSearchParams.mockReturnValue({ slug: "waterfront-north" });
  mockUseTotem.mockReturnValue({ ...defaultHook });
});

describe("TotemBoardScreen rendering", () => {
  it("renders the totem name", () => {
    render(<TotemBoardScreen />);
    expect(screen.getByText("Waterfront North")).toBeTruthy();
  });

  it("renders location", () => {
    render(<TotemBoardScreen />);
    expect(screen.getByText("St. Petersburg")).toBeTruthy();
  });

  it("shows loading indicator while loading", () => {
    mockUseTotem.mockReturnValueOnce({ ...defaultHook, totem: null, loading: true });
    render(<TotemBoardScreen />);
    expect(screen.UNSAFE_getByType(require("react-native").ActivityIndicator)).toBeTruthy();
  });

  it("shows error state", () => {
    mockUseTotem.mockReturnValueOnce({
      ...defaultHook,
      totem: null,
      loading: false,
      error: "Totem not found",
    });
    render(<TotemBoardScreen />);
    expect(screen.getByText("Totem not found")).toBeTruthy();
  });

  it("shows empty state when totem is empty", () => {
    mockUseTotem.mockReturnValueOnce({
      ...defaultHook,
      totem: { ...baseTotem, empty: true },
    });
    render(<TotemBoardScreen />);
    expect(screen.getByText("This spot isn't active yet")).toBeTruthy();
  });
});

describe("auto-follow on scan", () => {
  it("calls toggleFollow when source=scan and following=false", async () => {
    const toggleFollow = jest.fn();
    mockUseLocalSearchParams.mockReturnValue({ slug: "waterfront-north", source: "scan" });
    mockUseTotem.mockReturnValue({
      ...defaultHook,
      totem: { ...baseTotem, following: false },
      toggleFollow,
    });
    render(<TotemBoardScreen />);
    await waitFor(() => {
      expect(toggleFollow).toHaveBeenCalledTimes(1);
    });
  });

  it("does NOT call toggleFollow when already following", async () => {
    const toggleFollow = jest.fn();
    mockUseLocalSearchParams.mockReturnValue({ slug: "waterfront-north", source: "scan" });
    mockUseTotem.mockReturnValue({
      ...defaultHook,
      totem: { ...baseTotem, following: true },
      toggleFollow,
    });
    render(<TotemBoardScreen />);
    await waitFor(() => expect(screen.getByText("Waterfront North")).toBeTruthy());
    expect(toggleFollow).not.toHaveBeenCalled();
  });

  it("does NOT call toggleFollow when unauthenticated (following=null)", async () => {
    const toggleFollow = jest.fn();
    mockUseLocalSearchParams.mockReturnValue({ slug: "waterfront-north", source: "scan" });
    mockUseTotem.mockReturnValue({
      ...defaultHook,
      totem: { ...baseTotem, following: null },
      toggleFollow,
    });
    render(<TotemBoardScreen />);
    await waitFor(() => expect(screen.getByText("Waterfront North")).toBeTruthy());
    expect(toggleFollow).not.toHaveBeenCalled();
  });

  it("does NOT call toggleFollow without source=scan", async () => {
    const toggleFollow = jest.fn();
    mockUseLocalSearchParams.mockReturnValue({ slug: "waterfront-north" });
    mockUseTotem.mockReturnValue({
      ...defaultHook,
      totem: { ...baseTotem, following: false },
      toggleFollow,
    });
    render(<TotemBoardScreen />);
    await waitFor(() => expect(screen.getByText("Waterfront North")).toBeTruthy());
    expect(toggleFollow).not.toHaveBeenCalled();
  });
});

describe("TotemBoardScreen — analytics", () => {
  it("fires totem_follow_toggled when star toggled to follow", async () => {
    render(<TotemBoardScreen />);
    await waitFor(() => screen.getByLabelText("Add to favorites"));
    fireEvent.press(screen.getByLabelText("Add to favorites"));
    expect(posthog.capture).toHaveBeenCalledWith("totem_follow_toggled", {
      totem_slug: "waterfront-north",
      action: "follow",
    });
  });

  it("fires totem_follow_toggled:unfollow when star toggled to unfavorite", async () => {
    mockUseTotem.mockReturnValueOnce({
      ...defaultHook,
      totem: { ...baseTotem, following: true },
    });
    render(<TotemBoardScreen />);
    await waitFor(() => screen.getByLabelText("Remove from favorites"));
    fireEvent.press(screen.getByLabelText("Remove from favorites"));
    expect(posthog.capture).toHaveBeenCalledWith("totem_follow_toggled", {
      totem_slug: "waterfront-north",
      action: "unfollow",
    });
  });

  it("fires host_subscribe_toggled when subscribe switch toggled", async () => {
    const { Switch } = require("react-native");
    const event = {
      id: 1,
      title: "Morning Run",
      slug: "morning-run",
      recurrence_rule: "FREQ=WEEKLY;BYDAY=MO",
      recurrence_label: "Weekly on Mondays",
      start_time: new Date().toISOString(),
      end_time: new Date().toISOString(),
      next_occurrence: new Date().toISOString(),
      chat_url: null,
      chat_platform: "whatsapp",
      status: "active",
      description: null,
      community_norms: null,
      window_state: "happening_now" as const,
      share_url: "https://signalfire.live/t/slug/e/event",
      calendar_url: "https://signalfire.live/t/slug/e/event/calendar.ics",
      host: { id: 42, name: "Host Name", blurb: null, slug: null, following: null, host_follow_id: null },
      user_checked_in: false,
      checked_in_at: null,
      following: false,
    };
    mockApi.post.mockResolvedValueOnce({});
    mockUseTotem.mockReturnValueOnce({
      ...defaultHook,
      totem: { ...baseTotem, active_now: [event] },
    });
    render(<TotemBoardScreen />);
    await waitFor(() => screen.getByText("Morning Run"));
    const switches = screen.UNSAFE_getAllByType(Switch);
    await act(async () => {
      fireEvent(switches[0], "valueChange", true);
    });
    expect(posthog.capture).toHaveBeenCalledWith("host_follow_toggled", {
      host_user_id: event.host.id,
      action: "follow",
    });
  });
});

describe("StarToggle", () => {
  it("renders Add to favorites button when not favorited", () => {
    render(<TotemBoardScreen />);
    expect(screen.getByLabelText("Add to favorites")).toBeTruthy();
  });

  it("renders Remove from favorites button when favorited", () => {
    mockUseTotem.mockReturnValueOnce({
      ...defaultHook,
      totem: { ...baseTotem, following: true },
    });
    render(<TotemBoardScreen />);
    expect(screen.getByLabelText("Remove from favorites")).toBeTruthy();
  });

  it("does not render StarToggle when following=null (unauthenticated)", () => {
    mockUseTotem.mockReturnValueOnce({
      ...defaultHook,
      totem: { ...baseTotem, following: null },
    });
    render(<TotemBoardScreen />);
    expect(screen.queryByLabelText("Add to favorites")).toBeNull();
    expect(screen.queryByLabelText("Remove from favorites")).toBeNull();
  });
});
