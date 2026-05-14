import React from "react";
import { render, screen } from "@testing-library/react-native";
import AppLayout from "../../app/(app)/_layout";

// TabIcon is a private component rendered by the tabBarIcon option. We test it
// indirectly by inspecting the Tabs.Screen options passed to the Tabs mock.
// We also render it directly by extracting it from the screen options.

describe("AppLayout", () => {
  it("renders a Tabs navigator", () => {
    const { UNSAFE_getByType } = render(<AppLayout />);
    expect(UNSAFE_getByType(require("expo-router").Tabs)).toBeTruthy();
  });

  it("renders without crashing", () => {
    expect(() => render(<AppLayout />)).not.toThrow();
  });

  it("defines six tab screens", () => {
    const { UNSAFE_getAllByType } = render(<AppLayout />);
    const screens = UNSAFE_getAllByType(require("expo-router").Tabs.Screen);
    expect(screens).toHaveLength(6);
  });

  it("tab screens have correct names", () => {
    const { UNSAFE_getAllByType } = render(<AppLayout />);
    const screens = UNSAFE_getAllByType(require("expo-router").Tabs.Screen);
    const names = screens.map((s: any) => s.props.name);
    expect(names).toEqual(["index", "scan", "me", "signals", "totem", "host"]);
  });

  it("tab screens have correct titles", () => {
    const { UNSAFE_getAllByType } = render(<AppLayout />);
    const screens = UNSAFE_getAllByType(require("expo-router").Tabs.Screen);
    const titles = screens.map((s: any) => s.props.options?.title);
    expect(titles).toEqual(["Home", "Scan", "Profile", undefined, undefined, undefined]);
  });

  it("totem screen is hidden from the tab bar via href: null", () => {
    const { UNSAFE_getAllByType } = render(<AppLayout />);
    const screens = UNSAFE_getAllByType(require("expo-router").Tabs.Screen);
    const totemScreen = screens.find((s: any) => s.props.name === "totem");
    expect(totemScreen?.props.options?.href).toBeNull();
  });

  it("host screen is hidden from the tab bar via href: null", () => {
    const { UNSAFE_getAllByType } = render(<AppLayout />);
    const screens = UNSAFE_getAllByType(require("expo-router").Tabs.Screen);
    const hostScreen = screens.find((s: any) => s.props.name === "host");
    expect(hostScreen?.props.options?.href).toBeNull();
  });

  it("TabIcon renders the correct label", () => {
    const { UNSAFE_getAllByType } = render(<AppLayout />);
    const screens = UNSAFE_getAllByType(require("expo-router").Tabs.Screen);
    // Render each tabBarIcon and check the label text
    const homeIcon = screens[0].props.options.tabBarIcon({ focused: false });
    const { getByText } = render(homeIcon);
    expect(getByText("⌂")).toBeTruthy();
  });

  it("TabIcon for scan renders ⬛", () => {
    const { UNSAFE_getAllByType } = render(<AppLayout />);
    const screens = UNSAFE_getAllByType(require("expo-router").Tabs.Screen);
    const scanIcon = screens[1].props.options.tabBarIcon({ focused: false });
    const { getByText } = render(scanIcon);
    expect(getByText("⬛")).toBeTruthy();
  });

  it("signals screen is hidden from the tab bar via href: null", () => {
    const { UNSAFE_getAllByType } = render(<AppLayout />);
    const screens = UNSAFE_getAllByType(require("expo-router").Tabs.Screen);
    const signalsScreen = screens.find((s: any) => s.props.name === "signals");
    expect(signalsScreen?.props.options?.href).toBeNull();
  });

  it("TabIcon for profile (me) renders ◉", () => {
    const { UNSAFE_getAllByType } = render(<AppLayout />);
    const screens = UNSAFE_getAllByType(require("expo-router").Tabs.Screen);
    const profileScreen = screens.find((s: any) => s.props.name === "me");
    const icon = profileScreen?.props.options.tabBarIcon({ focused: false });
    const { getByText } = render(icon);
    expect(getByText("◉")).toBeTruthy();
  });
});
