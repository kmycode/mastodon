import { useEffect, useState, useCallback, useId } from 'react';

import { FormattedMessage, useIntl, defineMessages } from 'react-intl';

import { isFulfilled } from '@reduxjs/toolkit';

import { BookmarkSimpleIcon, XIcon } from '@phosphor-icons/react';

import {
  performBookmarkSuccess,
  unbookmark,
} from '@/mastodon/actions/interactions';
import { Toggle } from '@/mastodon/components/form_fields';
import { bookmarkCategoryNeeded } from '@/mastodon/initial_state';
import { fetchBookmarkCategories } from 'mastodon/actions/bookmark_categories';
import { createBookmarkCategory } from 'mastodon/actions/bookmark_categories_typed';
import {
  apiGetStatusBookmarkCategories,
  apiAddStatusToBookmarkCategory,
  apiRemoveStatusFromBookmarkCategory,
} from 'mastodon/api/bookmark_categories';
import type { ApiBookmarkCategoryJSON } from 'mastodon/api_types/bookmark_categories';
import { Button, IconButton } from 'mastodon/components/button/redesign';
import { Icon } from 'mastodon/components/icon';
import { NavigationFocusTarget } from 'mastodon/components/navigation_focus_target';
import { getOrderedBookmarkCategories } from 'mastodon/selectors/bookmark_categories';
import { useAppDispatch, useAppSelector } from 'mastodon/store';

const messages = defineMessages({
  newItem: {
    id: 'bookmark_categories.new_bookmark_category_name',
    defaultMessage: 'New bookmark_category name',
  },
  createBookmarkCategory: {
    id: 'bookmark_categories.create',
    defaultMessage: 'Create',
  },
  close: {
    id: 'lightbox.close',
    defaultMessage: 'Close',
  },
});

const BookmarkCategoryItem: React.FC<{
  id: string;
  title: string;
  checked: boolean;
  onChange: (id: string, checked: boolean) => void;
}> = ({ id, title, checked, onChange }) => {
  const uniqueId = useId();

  const handleChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      onChange(id, e.target.checked);
    },
    [id, onChange],
  );

  return (
    <label className='lists__item' htmlFor={uniqueId}>
      <div className='lists__item__title'>
        <Icon id='list-ul' icon={BookmarkSimpleIcon} />
        <span>{title}</span>
      </div>

      <Toggle id={uniqueId} checked={checked} onChange={handleChange} />
    </label>
  );
};

const NewBookmarkCategoryItem: React.FC<{
  onCreate: (bookmarkCategory: ApiBookmarkCategoryJSON) => void;
}> = ({ onCreate }) => {
  const intl = useIntl();
  const dispatch = useAppDispatch();
  const [title, setTitle] = useState('');

  const handleChange = useCallback(
    ({ target: { value } }: React.ChangeEvent<HTMLInputElement>) => {
      setTitle(value);
    },
    [setTitle],
  );

  const handleSubmit = useCallback(() => {
    if (title.trim().length === 0) {
      return;
    }

    void dispatch(createBookmarkCategory({ title })).then((result) => {
      if (isFulfilled(result)) {
        onCreate(result.payload);
        setTitle('');
      }

      return '';
    });
  }, [setTitle, dispatch, onCreate, title]);

  return (
    <form className='lists__item' onSubmit={handleSubmit}>
      <label className='lists__item__title'>
        <Icon id='list-ul' icon={BookmarkSimpleIcon} />

        <input
          type='text'
          value={title}
          onChange={handleChange}
          maxLength={30}
          required
          placeholder={intl.formatMessage(messages.newItem)}
        />
      </label>

      <Button type='submit' variant='solid' color='accent' size='sm'>
        {intl.formatMessage(messages.createBookmarkCategory)}
      </Button>
    </form>
  );
};

const BookmarkCategoryAdder: React.FC<{
  statusId: string;
  onClose: () => void;
}> = ({ statusId, onClose }) => {
  const intl = useIntl();
  const dispatch = useAppDispatch();
  const status = useAppSelector((state) => state.statuses.get(statusId));
  const bookmarkCategories = useAppSelector((state) =>
    getOrderedBookmarkCategories(state),
  );
  const [bookmarkCategoryIds, setBookmarkCategoryIds] = useState<string[]>([]);

  useEffect(() => {
    void dispatch(fetchBookmarkCategories());

    apiGetStatusBookmarkCategories(statusId)
      .then((data) => {
        setBookmarkCategoryIds(data.map((l) => l.id));
        return '';
      })
      .catch(() => {
        // Nothing
      });
  }, [dispatch, setBookmarkCategoryIds, statusId]);

  const handleToggle = useCallback(
    (bookmarkCategoryId: string, checked: boolean) => {
      if (checked) {
        setBookmarkCategoryIds((currentBookmarkCategoryIds) => [
          bookmarkCategoryId,
          ...currentBookmarkCategoryIds,
        ]);

        apiAddStatusToBookmarkCategory(bookmarkCategoryId, statusId).catch(
          () => {
            setBookmarkCategoryIds((currentBookmarkCategoryIds) =>
              currentBookmarkCategoryIds.filter(
                (id) => id !== bookmarkCategoryId,
              ),
            );
          },
        );

        if (
          bookmarkCategoryNeeded &&
          !bookmarkCategoryIds.some(
            (categoryId) => categoryId !== bookmarkCategoryId,
          )
        ) {
          dispatch(performBookmarkSuccess(status));
        }
      } else {
        setBookmarkCategoryIds((currentBookmarkCategoryIds) =>
          currentBookmarkCategoryIds.filter((id) => id !== bookmarkCategoryId),
        );

        apiRemoveStatusFromBookmarkCategory(bookmarkCategoryId, statusId).catch(
          () => {
            setBookmarkCategoryIds((currentBookmarkCategoryIds) => [
              bookmarkCategoryId,
              ...currentBookmarkCategoryIds,
            ]);
          },
        );

        // これreducerに移すべきでは？
        if (
          bookmarkCategoryNeeded &&
          !bookmarkCategoryIds.some(
            (categoryId) => categoryId !== bookmarkCategoryId,
          )
        ) {
          dispatch(unbookmark(status));
        }
      }
    },
    [setBookmarkCategoryIds, statusId, dispatch, status, bookmarkCategoryIds],
  );

  const handleCreate = useCallback(
    (bookmarkCategory: ApiBookmarkCategoryJSON) => {
      setBookmarkCategoryIds((currentBookmarkCategoryIds) => [
        bookmarkCategory.id,
        ...currentBookmarkCategoryIds,
      ]);

      apiAddStatusToBookmarkCategory(bookmarkCategory.id, statusId).catch(
        () => {
          setBookmarkCategoryIds((currentBookmarkCategoryIds) =>
            currentBookmarkCategoryIds.filter(
              (id) => id !== bookmarkCategory.id,
            ),
          );
        },
      );
    },
    [setBookmarkCategoryIds, statusId],
  );

  return (
    <div className='modal-root__modal dialog-modal'>
      <div className='dialog-modal__header'>
        <IconButton
          className='dialog-modal__header__close'
          icon={XIcon}
          onClick={onClose}
          size='sm'
          variant='ghost'
        >
          {intl.formatMessage(messages.close)}
        </IconButton>

        <NavigationFocusTarget as='h1' className='dialog-modal__header__title'>
          <FormattedMessage
            id='bookmark_categories.add_to_bookmark_category'
            defaultMessage='Add {name} to bookmark_categories'
            values={{ name: <strong>{statusId}</strong> }}
          />
        </NavigationFocusTarget>
      </div>

      <div className='dialog-modal__content'>
        <div className='bookmarkCategories-scrollable'>
          <NewBookmarkCategoryItem onCreate={handleCreate} />

          {bookmarkCategories.map((bookmarkCategory) => (
            <BookmarkCategoryItem
              key={bookmarkCategory.id}
              id={bookmarkCategory.id}
              title={bookmarkCategory.title}
              checked={bookmarkCategoryIds.includes(bookmarkCategory.id)}
              onChange={handleToggle}
            />
          ))}
        </div>
      </div>
    </div>
  );
};

// eslint-disable-next-line import/no-default-export
export default BookmarkCategoryAdder;
