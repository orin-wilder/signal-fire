jest.mock("../../services/api", () => ({
  api: {
    get: jest.fn(),
    patch: jest.fn(),
    delete: jest.fn(),
  },
}));

import { renderHook, act } from "@testing-library/react-native";
import { api } from "../../services/api";
import { useSubscriptions } from "../../hooks/useSubscriptions";

const mockApi = api as jest.Mocked<typeof api>;

const follow1 = {
  id: 1,
  totem_id: 10,
  totem_name: "Waterfront North",
  totem_slug: "waterfront-north",
  notify_new_event: true,
  notify_reminder: false,
};

const follow2 = {
  id: 2,
  totem_id: 20,
  totem_name: "Williams Park",
  totem_slug: "williams-park",
  notify_new_event: false,
  notify_reminder: true,
};

const sub1 = {
  id: 1,
  host_user_id: 100,
  host_name: "Maria Santos",
  notify_new_event: true,
  notify_reminder: true,
};

beforeEach(() => {
  jest.clearAllMocks();
});

describe("load", () => {
  it("fetches and sets follows and hostFollows", async () => {
    mockApi.get.mockResolvedValueOnce({
      totem_favorites: [follow1, follow2],
      host_follows: [sub1],
    });
    const { result } = renderHook(() => useSubscriptions());
    await act(async () => {
      await result.current.load();
    });
    expect(result.current.follows).toEqual([follow1, follow2]);
    expect(result.current.hostFollows).toEqual([sub1]);
    expect(result.current.loading).toBe(false);
  });

  it("leaves state empty on error", async () => {
    mockApi.get.mockRejectedValueOnce(new Error("Network error"));
    const { result } = renderHook(() => useSubscriptions());
    await act(async () => {
      await result.current.load();
    });
    expect(result.current.follows).toEqual([]);
    expect(result.current.hostFollows).toEqual([]);
    expect(result.current.loading).toBe(false);
  });
});

describe("unfollow", () => {
  it("DELETEs by record id and removes from state", async () => {
    mockApi.get.mockResolvedValueOnce({
      totem_favorites: [follow1, follow2],
      host_follows: [],
    });
    mockApi.delete.mockResolvedValueOnce(undefined);
    const { result } = renderHook(() => useSubscriptions());
    await act(async () => {
      await result.current.load();
    });
    await act(async () => {
      await result.current.unfollow(follow1.id);
    });
    expect(mockApi.delete).toHaveBeenCalledWith("/api/v1/totem_favorites/1");
    expect(result.current.follows).toEqual([follow2]);
  });
});

describe("unfollowHost", () => {
  it("DELETEs by record id and removes from state", async () => {
    mockApi.get.mockResolvedValueOnce({
      totem_favorites: [],
      host_follows: [sub1],
    });
    mockApi.delete.mockResolvedValueOnce(undefined);
    const { result } = renderHook(() => useSubscriptions());
    await act(async () => {
      await result.current.load();
    });
    await act(async () => {
      await result.current.unfollowHost(sub1.id);
    });
    expect(mockApi.delete).toHaveBeenCalledWith("/api/v1/host_follows/1");
    expect(result.current.hostFollows).toEqual([]);
  });
});

describe("updateFollow", () => {
  it("PATCHes and updates the follow in state", async () => {
    mockApi.get.mockResolvedValueOnce({
      totem_favorites: [follow1],
      host_follows: [],
    });
    mockApi.patch.mockResolvedValueOnce(undefined);
    const { result } = renderHook(() => useSubscriptions());
    await act(async () => {
      await result.current.load();
    });
    await act(async () => {
      await result.current.updateFollow(1, { notify_new_event: false });
    });
    expect(mockApi.patch).toHaveBeenCalledWith(
      "/api/v1/totem_favorites/1",
      { notify_new_event: false }
    );
    expect(result.current.follows[0].notify_new_event).toBe(false);
  });
});

describe("updateHostFollow", () => {
  it("PATCHes and updates the host follow in state", async () => {
    mockApi.get.mockResolvedValueOnce({
      totem_favorites: [],
      host_follows: [sub1],
    });
    mockApi.patch.mockResolvedValueOnce(undefined);
    const { result } = renderHook(() => useSubscriptions());
    await act(async () => {
      await result.current.load();
    });
    await act(async () => {
      await result.current.updateHostFollow(1, { notify_reminder: false });
    });
    expect(mockApi.patch).toHaveBeenCalledWith(
      "/api/v1/host_follows/1",
      { notify_reminder: false }
    );
    expect(result.current.hostFollows[0].notify_reminder).toBe(false);
  });
});
