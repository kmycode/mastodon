import { useCallback, useState, useEffect } from 'react';

import { defineMessages, useIntl, FormattedMessage } from 'react-intl';

import { useParams, useHistory, Link } from 'react-router-dom';

import { isFulfilled } from '@reduxjs/toolkit';

import { Helmet } from '@unhead/react/helmet';

import type { Circle } from '@/mastodon/models/circle';
import CircleIcon from '@/material-icons/400-24px/account_circle.svg?react';
import { fetchCircle } from 'mastodon/actions/circles';
import { createCircle, updateCircle } from 'mastodon/actions/circles_typed';
import { apiGetAccounts } from 'mastodon/api/circles';
import { Column } from 'mastodon/components/column';
import { ColumnHeader } from 'mastodon/components/column/header';
import { TextInputField } from 'mastodon/components/form_fields';
import { LoadingIndicator } from 'mastodon/components/loading_indicator';
import { useAppDispatch, useAppSelector } from 'mastodon/store';

const messages = defineMessages({
  edit: { id: 'column.edit_circle', defaultMessage: 'Edit circle' },
  create: { id: 'column.create_circle', defaultMessage: 'Create circle' },
});

const MembersLink: React.FC<{
  id: string;
}> = ({ id }) => {
  const [count, setCount] = useState(0);
  const [avatars, setAvatars] = useState<string[]>([]);

  useEffect(() => {
    void apiGetAccounts(id)
      .then((data) => {
        setCount(data.length);
        setAvatars(data.slice(0, 3).map((a) => a.avatar));
        return '';
      })
      .catch(() => {
        // Nothing
      });
  }, [id, setCount, setAvatars]);

  return (
    <Link to={`/circles/${id}/members`} className='app-form__link'>
      <div className='app-form__link__text'>
        <strong>
          <FormattedMessage
            id='circles.circle_members'
            defaultMessage='Circle members'
          />
        </strong>
        <FormattedMessage
          id='circles.circle_members_count'
          defaultMessage='{count, plural, one {# member} other {# members}}'
          values={{ count }}
        />
      </div>

      <div className='avatar-pile'>
        {avatars.map((url) => (
          <img key={url} src={url} alt='' />
        ))}
      </div>
    </Link>
  );
};

const NewCircle: React.FC<{
  circle?: Circle | null;
}> = ({ circle }) => {
  const dispatch = useAppDispatch();
  const history = useHistory();

  const { id, title: initialTitle = '' } = circle ?? {};

  const [title, setTitle] = useState(initialTitle);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    if (id) {
      dispatch(fetchCircle(id));
    }
  }, [dispatch, id]);

  const handleTitleChange = useCallback(
    ({ target: { value } }: React.ChangeEvent<HTMLInputElement>) => {
      setTitle(value);
    },
    [setTitle],
  );

  const handleSubmit = useCallback(() => {
    setSubmitting(true);

    if (id) {
      void dispatch(
        updateCircle({
          id,
          title,
        }),
      ).then(() => {
        setSubmitting(false);
        return '';
      });
    } else {
      void dispatch(
        createCircle({
          title,
        }),
      ).then((result) => {
        setSubmitting(false);

        if (isFulfilled(result)) {
          history.replace(`/circles/${result.payload.id}/edit`);
          history.push(`/circles/${result.payload.id}/members`);
        }

        return '';
      });
    }
  }, [history, dispatch, setSubmitting, id, title]);

  return (
    <form className='simple_form app-form' onSubmit={handleSubmit}>
      <div className='fields-group'>
        <TextInputField
          label={
            <FormattedMessage
              id='circles.circle_name'
              defaultMessage='Circle name'
            />
          }
          id='circle_title'
          type='text'
          value={title}
          onChange={handleTitleChange}
          maxLength={30}
          required
          placeholder=' '
        />
      </div>

      {id && (
        <div className='fields-group'>
          <MembersLink id={id} />
        </div>
      )}
      {!id && (
        <div className='fields-group'>
          <div className='app-form__memo'>
            <FormattedMessage
              id='circles.save_to_edit_member'
              defaultMessage='You can edit circle members after saving.'
            />
          </div>
        </div>
      )}

      <div className='actions'>
        <button className='button' type='submit'>
          {submitting ? (
            <LoadingIndicator />
          ) : id ? (
            <FormattedMessage id='circles.save' defaultMessage='Save' />
          ) : (
            <FormattedMessage id='circles.create' defaultMessage='Create' />
          )}
        </button>
      </div>
    </form>
  );
};

const NewCircleWrapper: React.FC<{
  multiColumn?: boolean;
}> = ({ multiColumn }) => {
  const intl = useIntl();
  const dispatch = useAppDispatch();
  const { id } = useParams<{ id?: string }>();
  const circle = useAppSelector((state) =>
    id ? state.circles.get(id) : undefined,
  );

  useEffect(() => {
    if (id) {
      dispatch(fetchCircle(id));
    }
  }, [dispatch, id]);

  const isLoading = id && !circle;

  return (
    <Column
      bindToDocument={!multiColumn}
      label={intl.formatMessage(id ? messages.edit : messages.create)}
    >
      <ColumnHeader
        title={intl.formatMessage(id ? messages.edit : messages.create)}
        icon='list-ul'
        iconComponent={CircleIcon}
        multiColumn={multiColumn}
        showBackButton
      />

      <div className='scrollable'>
        {isLoading ? <LoadingIndicator /> : <NewCircle circle={circle} />}
      </div>

      <Helmet>
        <title>
          {intl.formatMessage(id ? messages.edit : messages.create)}
        </title>
        <meta name='robots' content='noindex' />
      </Helmet>
    </Column>
  );
};

// eslint-disable-next-line import/no-default-export
export default NewCircleWrapper;
