jest.mock("../../hooks/useSubscriptions", () => ({
  useSubscriptions: jest.fn(),
}));

jest.mock("../../hooks/useAuth", () => ({
  useAuth: jest.fn(),
}));

jest.mock("../../services/api", () => ({
  api: {
    get: jest.fn(),
    patch: jest.fn(),
  },
}));

import { posthog } from "../../services/analytics";

import React from "react";
import { Switch } from "react-native";
import { render, screen, fireEvent, act } from "@testing-library/react-native";
import { useSubscriptions } from "../../hooks/useSubscriptions";
import { useAuth } from "../../hooks/useAuth";
import { api } from "../../services/api";
import SignalsScreen from "../../app/(app)/signals";

const mockUseSubscriptions = useSubscriptions as jest.MockedFunction<typeof useSubscriptions>;
const mockUseAuth = useAuth as jest.MockedFunction<typeof useAuth>;
const mockApi = api as jest.Mocked<typeof api>;

const follow = {
  id: 1,
  totem_id: 10,
  totem_name: "Waterfront North",
  totem_slug: "waterfront-north",
  notify_new_event: true,
  notify_reminder: false,
};

const hostFollow = {
  id: 1,
  host_user_id: 100,
  host_name: "Maria Santos",
  notify_new_event: true,
  notify_reminder: true,
};

const defaultHook = {
  follows: [],
  hostFollows: [],
  loading: false,
  load: jest.fn(),
  unfollow: jest.fn(),
  unfollowHost: jest.fn(),
  updateFollow: jest.fn(),
  updateHostFollow: jest.fn(),
};

const defaultUser = {
  id: 1,
  email: "test@example.com",
  name: "Test User",
  auth_method: "email",
  push_token: null,
  notification_prefs: { new_event: true, reminder: true, all: true },
};

const defaultAuth = {
  user: defaultUser,
  loading: false,
  signUp: jest.fn(),
  signIn: jest.fn(),
  signInWithGoogle: jest.fn(),
  signOut: jest.fn(),
  deleteAccount: jest.fn(),
  refreshUser: jest.fn(),
};

beforeEach(() => {
  jest.clearAllMocks();
  mockUseSubscriptions.mockReturnValue({ ...defaultHook });
  mockUseAuth.mockReturnValue({ ...defaultAuth });
  mockApi.patch.mockResolvedValue(undefined);
});

describe("SignalsScreen", () => {
  it("shows loading indicator initially", () => {
    mockUseSubscriptions.mockReturnValueOnce({ ...defaultHook, loading: true });
    render(<SignalsScreen />);
    expect(screen.UNSAFE_getByType(require("react-native").ActivityIndicator)).toBeTruthy();
  });

  it("shows empty state when no follows or host follows", () => {
    render(<SignalsScreen />);
    expect(screen.getByText(/Follow hosts and favorite places/)).toBeTruthy();
  });

  it("shows favorite places section", () => {
    mockUseSubscriptions.mockReturnValueOnce({ ...defaultHook, follows: [follow] });
    render(<SignalsScreen />);
    expect(screen.getByText("FAVORITE PLACES · 1")).toBeTruthy();
    expect(screen.getByText("Waterfront North")).toBeTruthy();
  });

  it("shows hosts you follow section", () => {
    mockUseSubscriptions.mockReturnValueOnce({ ...defaultHook, hostFollows: [hostFollow] });
    render(<SignalsScreen />);
    expect(screen.getByText("HOSTS YOU FOLLOW · 1")).toBeTruthy();
    expect(screen.getByText("Maria Santos")).toBeTruthy();
  });

  it("calls unfollow when Unfollow is pressed on a totem", async () => {
    const unfollow = jest.fn().mockResolvedValueOnce(undefined);
    mockUseSubscriptions.mockReturnValueOnce({ ...defaultHook, follows: [follow], unfollow });
    render(<SignalsScreen />);
    await act(async () => {
      fireEvent.press(screen.getByText("Unfollow"));
    });
    expect(unfollow).toHaveBeenCalledWith(follow.id);
  });

  it("calls unfollowHost when Unfollow is pressed on a host", async () => {
    const unfollowHost = jest.fn().mockResolvedValueOnce(undefined);
    mockUseSubscriptions.mockReturnValueOnce({
      ...defaultHook,
      hostFollows: [hostFollow],
      unfollowHost,
    });
    render(<SignalsScreen />);
    await act(async () => {
      fireEvent.press(screen.getByText("Unfollow"));
    });
    expect(unfollowHost).toHaveBeenCalledWith(hostFollow.id);
  });

  it("calls updateFollow when new event switch is toggled", async () => {
    const updateFollow = jest.fn().mockResolvedValueOnce(undefined);
    mockUseSubscriptions.mockReturnValueOnce({ ...defaultHook, follows: [follow], updateFollow });
    render(<SignalsScreen />);
    // index 0 = master toggle, index 1 = follow new event, index 2 = follow reminder
    const switches = screen.UNSAFE_getAllByType(Switch);
    await act(async () => {
      fireEvent(switches[1], "valueChange", false);
    });
    expect(updateFollow).toHaveBeenCalledWith(follow.id, { notify_new_event: false });
  });
});

describe("master toggle", () => {
  it("shows master toggle with All notifications label", () => {
    render(<SignalsScreen />);
    expect(screen.getByText("All notifications")).toBeTruthy();
    expect(screen.getByText(/Master toggle/)).toBeTruthy();
  });

  it("master switch is on when notification_prefs.all is true", () => {
    render(<SignalsScreen />);
    const switches = screen.UNSAFE_getAllByType(Switch);
    expect(switches[0].props.value).toBe(true);
  });

  it("master switch is off when notification_prefs.all is false", () => {
    mockUseAuth.mockReturnValueOnce({
      ...defaultAuth,
      user: { ...defaultUser, notification_prefs: { new_event: true, reminder: true, all: false } },
    });
    render(<SignalsScreen />);
    const switches = screen.UNSAFE_getAllByType(Switch);
    expect(switches[0].props.value).toBe(false);
  });

  it("PATCHes /api/v1/me and refreshes user when master toggled off", async () => {
    const refreshUser = jest.fn();
    mockUseAuth.mockReturnValueOnce({ ...defaultAuth, refreshUser });
    render(<SignalsScreen />);
    const switches = screen.UNSAFE_getAllByType(Switch);
    await act(async () => {
      fireEvent(switches[0], "valueChange", false);
    });
    expect(mockApi.patch).toHaveBeenCalledWith("/api/v1/me", {
      notification_prefs: { all: false },
    });
    expect(refreshUser).toHaveBeenCalled();
  });

  it("row switches are disabled and show off when master is off", () => {
    mockUseAuth.mockReturnValueOnce({
      ...defaultAuth,
      user: { ...defaultUser, notification_prefs: { new_event: true, reminder: true, all: false } },
    });
    mockUseSubscriptions.mockReturnValueOnce({
      ...defaultHook,
      follows: [follow],
      hostFollows: [hostFollow],
    });
    render(<SignalsScreen />);
    const switches = screen.UNSAFE_getAllByType(Switch);
    // master=0, follow new_event=1, follow reminder=2, hostFollow new_event=3, hostFollow reminder=4
    for (let i = 1; i < switches.length; i++) {
      expect(switches[i].props.value).toBe(false);
      expect(switches[i].props.disabled).toBe(true);
    }
  });

  it("row switches are enabled and show real values when master is on", () => {
    mockUseSubscriptions.mockReturnValueOnce({
      ...defaultHook,
      follows: [follow],
    });
    render(<SignalsScreen />);
    const switches = screen.UNSAFE_getAllByType(Switch);
    // follow.notify_new_event=true, follow.notify_reminder=false
    expect(switches[1].props.value).toBe(true);
    expect(switches[1].props.disabled).toBe(false);
    expect(switches[2].props.value).toBe(false);
    expect(switches[2].props.disabled).toBe(false);
  });
});

describe("SignalsScreen — analytics", () => {
  it("fires signals_tab_viewed on focus", () => {
    render(<SignalsScreen />);
    expect(posthog.capture).toHaveBeenCalledWith("signals_tab_viewed");
  });

  it("fires master_notifications_toggled when master switch toggled", async () => {
    render(<SignalsScreen />);
    const switches = screen.UNSAFE_getAllByType(Switch);
    await act(async () => {
      fireEvent(switches[0], "valueChange", false);
    });
    expect(posthog.capture).toHaveBeenCalledWith("master_notifications_toggled", { value: false });
  });
});
