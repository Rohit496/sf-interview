import { LightningElement } from 'lwc';
import counterStateManager from 'c/counterStateManager';

export default class LwcStateManagementDemo extends LightningElement {
    counter = counterStateManager();
}