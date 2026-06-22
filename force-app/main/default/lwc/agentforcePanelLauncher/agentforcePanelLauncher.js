import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
// The Agentforce Conversation Client (ACC) API gives us three methods:
//   open()    - opens the Agentforce side panel
//   close()   - closes the Agentforce side panel
//   execute() - sends a natural-language message (utterance) to the agent
import { open, close, execute } from 'lightning/accApi';

export default class AgentforcePanelLauncher extends LightningElement {
    // The Id of the Agentforce agent (bot) to talk to.
    // Defaults to the user's bot, but is overridable in Lightning App Builder.
    @api botId = '0Xxg5000000c2yTCAQ';

    // Text typed into the input box, bound to the lightning-input below.
    @track utterance = '';

    // Keep `utterance` in sync as the user types.
    handleUtteranceChange(event) {
        this.utterance = event.target.value;
    }

    // OPEN: opens the Agentforce side panel for the given bot.
    async handleOpen() {
        try {
            await open(this.botId);
        } catch (error) {
            this.showError('Could not open Agentforce', error);
        }
    }

    // CLOSE: closes the Agentforce side panel.
    async handleClose() {
        try {
            await close();
        } catch (error) {
            this.showError('Could not close Agentforce', error);
        }
    }

    // EXECUTE: sends the typed message to the agent, then clears the input.
    async handleExecute() {
        try {
            await execute(this.utterance, this.botId);
            this.utterance = '';
        } catch (error) {
            this.showError('Could not send message', error);
        }
    }

    // Small helper to show an error toast.
    showError(title, error) {
        const message = error?.body?.message || error?.message || 'Unknown error.';
        this.dispatchEvent(new ShowToastEvent({ title, message, variant: 'error' }));
    }
}
