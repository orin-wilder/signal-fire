import React from "react";
import { render, screen, fireEvent } from "@testing-library/react-native";
import { EventCard } from "../../components/EventCard";
import type { Event } from "../../hooks/useTotem";

const nextSunday = new Date();
nextSunday.setDate(nextSunday.getDate() + (7 - nextSunday.getDay()));
nextSunday.setHours(9, 0, 0, 0);

const baseEvent: Event = {
  id: 1,
  title: "Sunday Mass — Ecstatic Dance",
  slug: "ecstatic-dance",
  recurrence_rule: "FREQ=WEEKLY;BYDAY=SU",
  recurrence_label: "Weekly on Sundays",
  start_time: nextSunday.toISOString(),
  end_time: new Date(nextSunday.getTime() + 90 * 60000).toISOString(),
  next_occurrence: nextSunday.toISOString(),
  chat_url: "https://chat.whatsapp.com/test",
  chat_platform: "whatsapp",
  status: "active",
  description: "Come as you are.",
  community_norms: null,
  window_state: "upcoming",
  share_url: "https://signalfire.live/t/main-totem/e/ecstatic-dance",
  calendar_url: "https://signalfire.live/t/main-totem/e/ecstatic-dance/calendar.ics",
  host: { id: 10, name: "Maria Santos", blurb: "Welcomes newcomers every week.", slug: null, following: null, host_follow_id: null },
  user_checked_in: false,
  checked_in_at: null,
  following: false,
};

describe("EventCard", () => {
  it("renders event title and host name", () => {
    render(<EventCard event={baseEvent} onPress={jest.fn()} />);
    expect(screen.getByText("Sunday Mass — Ecstatic Dance")).toBeTruthy();
    expect(screen.getByText(/with Maria Santos/)).toBeTruthy();
  });

  it("renders host blurb when present", () => {
    render(<EventCard event={baseEvent} onPress={jest.fn()} />);
    expect(screen.getByText("Welcomes newcomers every week.")).toBeTruthy();
  });

  it("does not render blurb when absent", () => {
    const event = { ...baseEvent, host: { ...baseEvent.host, blurb: null } };
    render(<EventCard event={event} onPress={jest.fn()} />);
    expect(screen.queryByText("Welcomes newcomers every week.")).toBeNull();
  });

  it("shows HAPPENING NOW chip", () => {
    const event = { ...baseEvent, window_state: "happening_now" };
    render(<EventCard event={event} onPress={jest.fn()} />);
    expect(screen.getByText("HAPPENING NOW")).toBeTruthy();
  });

  it("shows STARTING SOON chip", () => {
    const event = { ...baseEvent, window_state: "starting_soon" };
    render(<EventCard event={event} onPress={jest.fn()} />);
    expect(screen.getByText("STARTING SOON")).toBeTruthy();
  });

  it("shows JUST ENDED chip", () => {
    const event = { ...baseEvent, window_state: "just_ended" };
    render(<EventCard event={event} onPress={jest.fn()} />);
    expect(screen.getByText("JUST ENDED")).toBeTruthy();
  });

  it("shows no chip for upcoming events", () => {
    render(<EventCard event={baseEvent} onPress={jest.fn()} />);
    expect(screen.queryByText("HAPPENING NOW")).toBeNull();
    expect(screen.queryByText("STARTING SOON")).toBeNull();
    expect(screen.queryByText("JUST ENDED")).toBeNull();
  });

  it("renders follow toggle when showFollowToggle is true", () => {
    render(
      <EventCard
        event={baseEvent}
        onPress={jest.fn()}
        showFollowToggle={true}
        onFollowChange={jest.fn()}
      />
    );
    expect(screen.getByText("Follow Maria Santos")).toBeTruthy();
  });

  it("does not render follow toggle when showFollowToggle is false", () => {
    render(<EventCard event={baseEvent} onPress={jest.fn()} showFollowToggle={false} />);
    expect(screen.queryByText("Follow Maria Santos")).toBeNull();
  });

  it("calls onPress when the card is tapped", () => {
    const onPress = jest.fn();
    render(<EventCard event={baseEvent} onPress={onPress} />);
    fireEvent.press(screen.getByText("Sunday Mass — Ecstatic Dance"));
    expect(onPress).toHaveBeenCalledTimes(1);
  });
});
