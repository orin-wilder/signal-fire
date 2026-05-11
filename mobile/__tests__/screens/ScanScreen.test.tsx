import React from "react";
import { render, screen, fireEvent, act } from "@testing-library/react-native";
import { Alert } from "react-native";
import { router } from "expo-router";
import { useCameraPermissions } from "expo-camera";
import ScanScreen from "../../app/(app)/scan";

const mockRouter = router as jest.Mocked<typeof router>;
const mockUseCameraPermissions = useCameraPermissions as jest.MockedFunction<typeof useCameraPermissions>;

beforeEach(() => {
  jest.clearAllMocks();
  jest.spyOn(Alert, "alert");
  // Default: permission granted
  mockUseCameraPermissions.mockReturnValue([{ granted: true } as any, jest.fn()]);
});

describe("ScanScreen — camera permission", () => {
  it("renders camera when permission granted", () => {
    render(<ScanScreen />);
    expect(screen.getByText("SCAN A TOTEM")).toBeTruthy();
  });

  it("shows permission request when not granted", () => {
    mockUseCameraPermissions.mockReturnValueOnce([{ granted: false } as any, jest.fn()]);
    render(<ScanScreen />);
    expect(screen.getByText("Camera access is needed to scan totem QR codes.")).toBeTruthy();
    expect(screen.getByText("Allow camera access")).toBeTruthy();
  });

  it("renders empty view while permission is loading", () => {
    mockUseCameraPermissions.mockReturnValueOnce([null as any, jest.fn()]);
    const { toJSON } = render(<ScanScreen />);
    // Returns empty View
    expect(screen.queryByText("SCAN A TOTEM")).toBeNull();
  });
});

describe("ScanScreen — QR scanning", () => {
  it("navigates to totem with source=scan on valid QR", () => {
    render(<ScanScreen />);
    const camera = screen.UNSAFE_getByType(require("expo-camera").CameraView);

    act(() => {
      camera.props.onBarcodeScanned({ data: "https://signalfire.live/t/waterfront-north" });
    });

    expect(mockRouter.push).toHaveBeenCalledWith({
      pathname: "/totem/waterfront-north",
      params: { source: "scan" },
    });
  });

  it("shows alert for invalid QR code", () => {
    render(<ScanScreen />);
    const camera = screen.UNSAFE_getByType(require("expo-camera").CameraView);

    act(() => {
      camera.props.onBarcodeScanned({ data: "https://not-signal-fire.com/something" });
    });

    expect(Alert.alert).toHaveBeenCalledWith(
      "Not a Signal Fire QR code",
      expect.any(String)
    );
    expect(mockRouter.push).not.toHaveBeenCalled();
  });

  it("does not navigate twice if scanned quickly twice", () => {
    render(<ScanScreen />);
    const camera = screen.UNSAFE_getByType(require("expo-camera").CameraView);

    act(() => {
      camera.props.onBarcodeScanned({ data: "https://signalfire.live/t/waterfront-north" });
      camera.props.onBarcodeScanned({ data: "https://signalfire.live/t/waterfront-north" });
    });

    expect(mockRouter.push).toHaveBeenCalledTimes(1);
  });
});

describe("ScanScreen — close button", () => {
  it("calls router.back on close", () => {
    render(<ScanScreen />);
    fireEvent.press(screen.getByText("Close"));
    expect(mockRouter.back).toHaveBeenCalled();
  });
});
