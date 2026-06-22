import { defineState } from "@lwc/state";

const counterStateManager = defineState(
  ({ atom, computed, setAtom }, initialValue = 0) => {
    const count = atom(initialValue);
    const history = atom([initialValue]);

    const doubleCount = computed([count], (countValue) => countValue * 2);
    const isPositive = computed([count], (countValue) => countValue > 0);
    const isNegative = computed([count], (countValue) => countValue < 0);

    const historyLength = computed(
      [history],
      (historyValue) => historyValue.length,
    );

    const setCount = (next) => {
      setAtom(count, next);
      setAtom(history, [...history.value, next]);
    };

    const increment = () => setCount(count.value + 1);
    const decrement = () => setCount(count.value - 1);
    const reset = () => setCount(initialValue);

    return {
      count,
      doubleCount,
      isPositive,
      isNegative,
      historyLength,
      increment,
      decrement,
      reset,
      setCount,
    };
  },
);

export default counterStateManager;