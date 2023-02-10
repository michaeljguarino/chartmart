import posthog from 'posthog-js'

import { ApolloError } from '@apollo/client'

import { Provider, User } from '../generated/graphql'

import { CloudProvider } from '../components/shell/onboarding/context/types'

import Cookiebot from './cookiebot'

export default function PosthogIdentify(me: User) {
  if (Cookiebot?.consent?.statistics) {
    posthog.identify(me.id)
    posthog.people.set({
      // should email be under the GDPR check?
      email: me.email,
      accountId: me.account?.id,
      accountName: me.account?.name,
      onboarding: me.onboarding,
      serviceAccount: me.serviceAccount,
      hasInstallations: me.hasInstallations,
    })
    if (!Cookiebot?.regulations?.gdprApplies) {
      posthog.people.set({
        name: me.name,
      })
    }
  }
}

export enum PosthogEvent {
  Onboarding = 'Onboarding',
  Installer = 'Installer',
  OIDCLogin = 'OIDC Login'
}

interface PosthogOnboardingEvent {
  provider?: CloudProvider
  error?: ApolloError
  clusterName?: string
}

interface PosthogInstallerEvent {
  error?: ApolloError
  applications?: Array<string>
  provider?: Provider
}

interface PosthogOIDCLoginEvent {
  applicationName?: string
  applicationID?: string
  installationID?: string
}

type PosthogEventData = {
  [PosthogEvent.Onboarding]: PosthogOnboardingEvent,
  [PosthogEvent.Installer]: PosthogInstallerEvent,
  [PosthogEvent.OIDCLogin]: PosthogOIDCLoginEvent
}

export function posthogCapture<T extends PosthogEvent>(event: T, data: PosthogEventData[T]): void {
  posthog.capture(event, data)
}
