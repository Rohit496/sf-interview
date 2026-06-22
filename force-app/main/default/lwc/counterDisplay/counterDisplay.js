import { LightningElement } from "lwc";
import { fromContext } from "@lwc/state";
import counterStateManager from "c/counterStateManager";

export default class CounterDisplay extends LightningElement {
  counter = fromContext(counterStateManager);

  get count() {
    return this.counter.value?.count;
  }

  get doubleCount() {
    return this.counter.value?.doubleCount;
  }

  get isPositive() {
    return this.counter.value?.isPositive;
  }

  get isNegative() {
    return this.counter.value?.isNegative;
  }

  get historyLength() {
    return this.counter.value?.historyLength;
  }

  handleZero() {
    this.counter.value?.setCount(0);
  }
}