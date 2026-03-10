import Toybox.WatchUi;
import Toybox.Lang;

(:high_res)
class EGYMWeightPickerDelegate extends WatchUi.BehaviorDelegate {
    private var _pickerViewRef as WeakReference;
    private var _mainViewRef as WeakReference;

    function initialize(view as EGYMWeightPickerView, mainView as EGYMView) {
        BehaviorDelegate.initialize();
        _pickerViewRef = view.weak();
        _mainViewRef = mainView.weak();
    }

    function onPreviousPage() as Boolean {
        if (!_pickerViewRef.stillAlive()) {
            return false;
        }
        var pickerView = _pickerViewRef.get() as EGYMWeightPickerView?;
        if (pickerView != null) {
            pickerView.changeWeight(1);
            return true;
        }
        return false;
    }

    function onNextPage() as Boolean {
        if (!_pickerViewRef.stillAlive()) {
            return false;
        }
        var pickerView = _pickerViewRef.get() as EGYMWeightPickerView?;
        if (pickerView != null) {
            pickerView.changeWeight(-1);
            return true;
        }
        return false;
    }

    function onSelect() as Boolean {
        var main = _mainViewRef.stillAlive() ? (_mainViewRef.get() as EGYMView?) : null;
        var picker = _pickerViewRef.stillAlive() ? (_pickerViewRef.get() as EGYMWeightPickerView?) : null;

        if (main != null && picker != null) {
            main.onWeightPicked(picker.getWeight());
            picker.release();
        } else if (picker != null) {
            picker.release();
        }

        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    function onBack() as Boolean {
        if (_mainViewRef.stillAlive()) {
            var mainView = _mainViewRef.get() as EGYMView?;
            if (mainView != null) {
                mainView.cancelWeightPicker();
            }
        }
        if (_pickerViewRef.stillAlive()) {
            var pickerView = _pickerViewRef.get() as EGYMWeightPickerView?;
            if (pickerView != null) {
                pickerView.release();
            }
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
