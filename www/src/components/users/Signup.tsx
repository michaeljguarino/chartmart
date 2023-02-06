import {
  ComponentProps,
  useCallback,
  useEffect,
  useRef,
  useState,
} from 'react'
import { Form } from 'grommet'
import { Link, useLocation } from 'react-router-dom'
import {
  A,
  Button,
  Div,
  P,
} from 'honorable'
import useScript from 'react-script-hook'

import { useOauthUrlsQuery, useSignupMutation } from '../../generated/graphql'
import { WelcomeHeader } from '../utils/WelcomeHeader'
import { fetchToken, setToken } from '../../helpers/authentication'
import { GqlError } from '../utils/Alert'
import { PasswordErrorCode, PasswordErrorMessage, validatePassword } from '../Login'
import { host } from '../../helpers/hostname'
import { useHistory } from '../../router'

import { getDeviceToken } from './utils'
import { finishedDeviceLogin } from './DeviceLoginNotif'
import { LabelledInput, LoginPortal, OAuthOptions } from './MagicLogin'

function PasswordErrorMsg({ errorCode }: { errorCode: PasswordErrorCode }) {
  return (
    <P
      caption
      color="text-error"
    >
      {PasswordErrorMessage[errorCode]}
    </P>
  )
}

export function SetPasswordField({
  errorCode,
  ...props
}: { errorCode: PasswordErrorCode } & ComponentProps<typeof LabelledInput>) {
  return (
    <LabelledInput
      label="Password"
      type="password"
      placeholder="Enter password"
      hint="10 character minimum"
      caption={
        errorCode === 'TOO_SHORT' && <PasswordErrorMsg errorCode={errorCode} />
      }
      {...props}
    />
  )
}

export function ConfirmPasswordField({
  errorCode,
  ...props
}: ComponentProps<typeof SetPasswordField>) {
  return (
    <LabelledInput
      label="Confirm password"
      type="password"
      placeholder="Confirm password"
      hint=""
      caption={
        errorCode === 'NO_MATCH' && <PasswordErrorMsg errorCode={errorCode} />
      }
      {...props}
    />
  )
}

export function Signup() {
  const history = useHistory()
  const location = useLocation()
  const [email, setEmail] = useState(location?.state?.email || '')
  const [password, setPassword] = useState('')
  const [name, setName] = useState('')
  const [account, setAccount] = useState('')
  const [confirm, setConfirm] = useState('')
  const deviceToken = getDeviceToken()
  const nameRef = useRef<HTMLElement>()
  const emailRef = useRef<HTMLElement>()
  const [mutation, { loading, error }] = useSignupMutation({
    variables: {
      attributes: { email, password, name },
      account: { name: account },
      deviceToken,
    },
    onCompleted: ({ signup }) => {
      if (deviceToken) {
        finishedDeviceLogin()
      }
      setToken(signup?.jwt)
      history.navigate('/shell')
    },
  })
  const { data } = useOauthUrlsQuery({ variables: { host: host() } })

  useEffect(() => {
    const ref = email ? nameRef : emailRef

    ref?.current?.querySelector('input')?.focus()
    // Only set focus on first render
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  useEffect(() => {
    if (fetchToken()) {
      history.navigate('/')
    }
  }, [history])
  useScript({ src: 'https://js.hs-scripts.com/22363579.js' })
  const submit = useCallback(() => {
    mutation()
  }, [mutation])

  const { disabled, error: passwordError } = validatePassword(password, confirm)

  const showEmailError = error?.message?.startsWith('not_found')

  return (
    <LoginPortal>
      <WelcomeHeader marginBottom="xxlarge" />
      <Form onSubmit={submit}>
        {!showEmailError && error && (
          <Div marginBottom="medium">
            <GqlError
              error={error}
              header="Signup failed"
            />
          </Div>
        )}
        <LabelledInput
          ref={emailRef}
          label="Email address"
          value={email}
          onChange={setEmail}
          placeholder="Enter email address"
        />
        <LabelledInput
          ref={nameRef}
          label="Username"
          value={name}
          onChange={setName}
          placeholder="Enter username"
        />
        <LabelledInput
          label="Company name"
          value={account}
          onChange={setAccount}
          placeholder="Enter company name"
        />
        <SetPasswordField
          value={password}
          onChange={setPassword}
          errorCode={passwordError}
        />
        <ConfirmPasswordField
          value={confirm}
          onChange={setConfirm}
          errorCode={passwordError}
        />
        <Button
          type="submit"
          primary
          width="100%"
          disabled={disabled}
          loading={loading}
        >
          Create account
        </Button>
      </Form>
      <OAuthOptions oauthUrls={data?.oauthUrls} />
      <P
        body2
        textAlign="center"
        marginTop="medium"
      >
        Already have an account?{' '}
        <A
          as={Link}
          inline
          to="/login"
        >
          Login
        </A>
      </P>
    </LoginPortal>
  )
}
