export type cookiebot = {
  consent: {
    necessary: boolean;
    preferences: boolean;
    statistics: boolean;
    marketing: boolean;
    method: string | null;
  };
  consented: boolean;
  declined: boolean;
  hasResponse: boolean;
  doNotTrack: boolean;
  regulations: {
    gdprApplies: boolean;
    ccpaApplies: boolean;
    lgpdApplies: boolean;
  }
  show(): void;
  hide(): void;
  renew(): void;
  getScript(url: string, async: boolean, callback: () => void): void;
  runScripts(): void;
  withdraw(): void;
  submitCustomConsent(optinPreferences: boolean, optinStatistics: boolean, optinMarketing: boolean): void;
}

const { Cookiebot } = window

export default Cookiebot
