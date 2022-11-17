import { useSearchParams } from 'react-router-dom'
import { useQuery } from '@apollo/client'

import { LoopingLogo } from '../utils/AnimatedLogo'

import { useHistory } from '../../router'

import { AUTHENTICATION_URLS_QUERY, SCM_TOKEN_QUERY } from './queries'

import OnboardingFlow from './onboarding/OnboardingFlow'
import { useDevToken } from './useDevToken'

function OAuthCallback({ provider }: any) {
  const history = useHistory()
  const [searchParams] = useSearchParams()
  const devToken = useDevToken()

  const { data: authUrlData } = useQuery(AUTHENTICATION_URLS_QUERY)

  let { data } = useQuery(SCM_TOKEN_QUERY, {
    variables: {
      code: searchParams.get('code'),
      provider: provider.toUpperCase(),
    },
  })

  // HACK to navigate the onboarding on staging environments
  if (import.meta.env.MODE !== 'production' && devToken) {
    data = { ...data, ...{ scmToken: devToken } }
  }

  if (!data) {
    return (
      <LoopingLogo />
    )
  }

  if (!data.scmToken) {
    history.navigate('/shell')

    return null
  }

  return (
    <OnboardingFlow
      accessToken={data.scmToken}
      provider={provider.toUpperCase()}
      authUrlData={authUrlData}
    />
  )
}

export default OAuthCallback
