import { LightningElement } from "lwc";
import { fromContext } from "@lwc/state";
import counterStateManager from "c/counterStateManager";

export default class CounterControls extends LightningElement {
  counter = fromContext(counterStateManager);
  inputValue = 0;

  handleIncrement() {
    this.counter.value?.increment();
  }

  handleDecrement() {
    this.counter.value?.decrement();
  }

  handleReset() {
    this.counter.value?.reset();
  }

  handleInputChange(event) {
    this.inputValue = Number(event.target.value);
  }

  handleApply() {
    this.counter.value?.setCount(this.inputValue);
  }
}